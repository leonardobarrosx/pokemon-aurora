package main

import (
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"time"
)

type Server struct {
	mu            sync.Mutex
	world         *World
	path          string
	registrations map[string]float64
}
type PublicPlayer struct {
	Look   map[string]string `json:"look"`
	Colors map[string]string `json:"colors"`
	ID     string            `json:"id"`
	Name   string            `json:"name"`
	Area   string            `json:"area"`
	Pos    Vec               `json:"pos"`
	Color  string            `json:"color"`
}
type Rank struct {
	Name    string             `json:"name"`
	Rating  int                `json:"rating"`
	Wins    int                `json:"wins"`
	Losses  int                `json:"losses"`
	Records map[string]float64 `json:"records"`
	Team    []int              `json:"team"`
}

func (s *Server) snapshot(p *Player, now float64) map[string]any {
	others := []PublicPlayer{}
	ranks := []Rank{}
	live := []*Battle{}
	for _, x := range s.world.Players {
		if now-x.Seen < 15 && x.ID != p.ID {
			others = append(others, PublicPlayer{x.Look, x.Colors, x.ID, x.Name, x.Area, x.Pos, x.Color})
		}
		team := []int{}
		for _, id := range x.Team {
			if m := x.mon(id); m != nil {
				team = append(team, m.Species)
			}
		}
		ranks = append(ranks, Rank{x.Name, x.Rating, x.Wins, x.Losses, x.Records, team})
	}
	sort.Slice(ranks, func(i, j int) bool { return ranks[i].Rating > ranks[j].Rating })
	if len(ranks) > 50 {
		ranks = ranks[:50]
	}
	for _, b := range s.world.Battles {
		if b.End == 0 && (b.Kind == "gym" || b.Kind == "pvp") {
			live = append(live, b)
		}
	}
	return map[string]any{"player": p, "players": others, "battle": s.world.Battles[p.Battle], "battles": live, "chat": s.world.Chat, "rankings": ranks, "now": now, "species": species, "market": s.world.Market, "regions": regionStatus(p)}
}
func (s *Server) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("Cache-Control", "no-store")
	if r.URL.Path == "/health" {
		fmt.Fprint(w, `{"ok":true,"game":"Pokémon Aurora Online","tick_rate":20}`)
		return
	}
	if r.URL.Path != "/api" || r.Method != "POST" {
		http.Error(w, `{"error":"rota inexistente"}`, 404)
		return
	}
	// Native client API: no CORS, cookie authentication or browser origins.
	if r.Header.Get("Origin") != "" {
		http.Error(w, `{"error":"cliente desktop necessário"}`, 403)
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, 8192)
	var c Command
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	if dec.Decode(&c) != nil {
		http.Error(w, `{"error":"comando inválido"}`, 400)
		return
	}
	if dec.Decode(&struct{}{}) != io.EOF {
		http.Error(w, `{"error":"JSON excedente"}`, 400)
		return
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	now := nowSec()
	if c.Type == "register" {
		name := strings.TrimSpace(c.Name)
		if len([]rune(name)) < 2 || len([]rune(name)) > 20 || strings.ContainsAny(name, "\n\r\t") {
			http.Error(w, `{"error":"nome deve ter de 2 a 20 caracteres"}`, 400)
			return
		}
		if c.Starter != 1 && c.Starter != 4 && c.Starter != 7 {
			http.Error(w, `{"error":"inicial inválido"}`, 400)
			return
		}
		if len(s.world.Players) >= 200 {
			http.Error(w, `{"error":"limite de 200 contas deste servidor alfa"}`, 503)
			return
		}
		p := newPlayer(name, c.Starter, now)
		if c.Area != "" && c.Area != "aurora" && c.Area != "kanto" {
			c.Area = "kanto" // a jornada começa em Kanto; as outras regiões abrem em ordem
		}
		if start, ok := regionStarts[c.Area]; ok && c.Area != "aurora" {
			// Começa em Kanto ou Hoenn, já com a jornada liberada nessa região.
			p.Area = start
			p.Pos = arrival(start, "")
			p.Visits[start] = true
			p.Notice = "Bem-vindo a " + map[string]string{"kanto": "Kanto", "hoenn": "Hoenn"}[c.Area] + "! Use o mapa para viajar entre as regiões quando quiser."
		}
		token := uid()
		s.world.Players[p.ID] = p
		s.world.Sessions[token] = p.ID
		out := s.snapshot(p, now)
		out["token"] = token
		if err := s.saveLocked(); err != nil {
			delete(s.world.Players, p.ID)
			delete(s.world.Sessions, token)
			http.Error(w, `{"error":"não foi possível salvar a conta"}`, 500)
			return
		}
		_ = json.NewEncoder(w).Encode(out)
		return
	}
	token := strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer ")
	id := s.world.Sessions[token]
	p := s.world.Players[id]
	if p == nil {
		http.Error(w, `{"error":"sessão inválida; conecte seu treinador"}`, 401)
		return
	}
	settleTraining(p, now)
	if p.Training != nil && now-p.Seen > 8*3600 {
		p.Training.At = now
	}
	p.Seen = now
	err := s.world.action(p, c, now)
	out := s.snapshot(p, now)
	if err != nil {
		out["error"] = err.Error()
	}
	_ = json.NewEncoder(w).Encode(out)
}
func (s *Server) saveLocked() error {
	data, err := json.Marshal(s.world)
	if err != nil {
		return err
	}
	if err = os.MkdirAll(filepath.Dir(s.path), 0700); err != nil {
		return err
	}
	tmp := s.path + ".tmp"
	f, err := os.OpenFile(tmp, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, 0600)
	if err != nil {
		return err
	}
	if _, err = f.Write(data); err == nil {
		err = f.Sync()
	}
	closeErr := f.Close()
	if err == nil {
		err = closeErr
	}
	if err != nil {
		return err
	}
	return os.Rename(tmp, s.path)
}
func load(path string) (*World, error) {
	b, e := os.ReadFile(path)
	if errors.Is(e, os.ErrNotExist) {
		return newWorld(), nil
	}
	if e != nil {
		return nil, e
	}
	w := newWorld()
	if e = json.Unmarshal(b, w); e != nil {
		return nil, e
	}
	for _, p := range w.Players {
		p.Battle = ""
		p.Arcade = nil
		p.Input = Vec{}
	}
	w.Battles = map[string]*Battle{}
	w.Queue = []string{}
	return w, nil
}
func main() {
	listen := flag.String("listen", "127.0.0.1:8787", "endereço HTTP; use proxy TLS para acesso pela internet")
	save := flag.String("data", "data/world.json", "arquivo de progresso")
	flag.Parse()
	world, err := load(*save)
	if err != nil {
		log.Fatal("não foi possível carregar progresso: ", err)
	}
	s := &Server{world: world, path: *save, registrations: map[string]float64{}}
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt)
	defer stop()
	go func() {
		tick := time.NewTicker(50 * time.Millisecond)
		defer tick.Stop()
		last := nowSec()
		saved := last
		for {
			select {
			case <-ctx.Done():
				return
			case <-tick.C:
				s.mu.Lock()
				now := nowSec()
				dt := min(.1, now-last)
				s.world.tick(dt, now)
				last = now
				if now-saved >= 2 {
					if err := s.saveLocked(); err != nil {
						log.Print("ERRO AO SALVAR: ", err)
					}
					saved = now
				}
				s.mu.Unlock()
			}
		}
	}()
	httpServer := &http.Server{Addr: *listen, Handler: s, ReadHeaderTimeout: 5 * time.Second, ReadTimeout: 10 * time.Second, WriteTimeout: 10 * time.Second, IdleTimeout: 30 * time.Second}
	go func() {
		log.Printf("Aurora Online em http://%s (20 ticks/s)", *listen)
		if err := httpServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatal(err)
		}
	}()
	<-ctx.Done()
	shutdown, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	_ = httpServer.Shutdown(shutdown)
	s.mu.Lock()
	defer s.mu.Unlock()
	if err := s.saveLocked(); err != nil {
		log.Print(err)
	}
}
