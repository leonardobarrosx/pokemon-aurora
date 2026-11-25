package main

import (
	"encoding/json"
	"testing"
)

func TestRegionInheritanceAndLegacySave(t *testing.T) {
	legacy := Genome{Loci: map[string]Locus{"body": {{1, 2}, {2, 2}}, "detail": {{3, 2}, {3, 2}}, "eye": {{5, 2}, {5, 2}}}}
	old := appearance(legacy)
	if old.Regions["skin"] != old.Body || old.Regions["fur"] != old.Body || old.Regions["flame"] != old.Detail {
		t.Fatal("legacy pigment lost")
	}
	a, b := Mon{Genes: legacy}, Mon{Genes: legacy}
	child := inherit(a, b, func() float64 { return 0 })
	if child.Loci["skin"][0] != legacy.Loci["body"][0] {
		t.Fatal("legacy allele not inherited")
	}
	child.Loci["flame"] = Locus{{6, 2}, {6, 2}}
	look := appearance(child)
	if look.Regions["flame"] == look.Regions["skin"] || look.Regions["eye"] != old.Regions["eye"] {
		t.Fatal("regions coupled")
	}
	bytes, err := json.Marshal(child)
	if err != nil {
		t.Fatal(err)
	}
	var saved Genome
	if err = json.Unmarshal(bytes, &saved); err != nil {
		t.Fatal(err)
	}
	if appearance(saved).Regions["flame"] != look.Regions["flame"] {
		t.Fatal("regional color lost after save")
	}
}
