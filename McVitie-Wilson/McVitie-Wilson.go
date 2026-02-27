package main

import (
	"encoding/csv"
	"fmt"
	"os"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"
)

// The Resident data type
type Resident struct {
	residentID     int
	firstname      string
	lastname       string
	rol            []string // resident rank order list
	matchedProgram string   // will be "" for unmatched resident
}

// The Program data type
type Program struct {
	programID         string
	name              string
	nPositions        int         // number of positions available (quota)
	rol               []int       // program rank order list
	rank              map[int]int // map from resident ID to rank
	selectedResidents []int       // TO ADD: a data structure for the selected resident IDs
}

// Parse a resident's ROL
func parseRol(s string) []string {
	s = strings.TrimSpace(s)
	s = strings.TrimPrefix(s, "[")
	s = strings.TrimSuffix(s, "]")
	if s == "" {
		return []string{}
	}
	parts := strings.Split(s, ",")
	for i, part := range parts {
		parts[i] = strings.TrimSpace(part)
	}
	return parts
}

// Parse a program's ROL
func parseIntRol(s string) []int {
	s = strings.TrimSpace(s)
	s = strings.TrimPrefix(s, "[")
	s = strings.TrimSuffix(s, "]")
	if s == "" {
		return []int{}
	}
	parts := strings.Split(s, ",")
	var ints []int
	for _, part := range parts {
		pid, _ := strconv.Atoi(strings.TrimSpace(part))
		ints = append(ints, pid)
	}
	return ints
}

// ReadCSV reads a CSV file into a map of Resident
func ReadResidentsCSV(filename string) (map[int]*Resident, error) {

	// map to store residents by ID
	residents := make(map[int]*Resident)

	file, err := os.Open(filename)
	if err != nil {
		return nil, fmt.Errorf("unable to open file: %w", err)
	}
	defer file.Close()

	reader := csv.NewReader(file)

	// Read all records
	records, err := reader.ReadAll()
	if err != nil {
		return nil, fmt.Errorf("error reading CSV: %w", err)
	}

	// Skip header if present (assuming it is)
	for i, record := range records {
		if i == 0 && record[0] == "id" {
			continue
		}
		if len(record) < 4 {
			return nil, fmt.Errorf("invalid record at line %d: %v", i+1, record)
		}

		// Parse ID
		id, err := strconv.Atoi(record[0])
		if err != nil {
			return nil, fmt.Errorf("invalid ID at line %d: %w", i+1, err)
		}

		if _, exists := residents[id]; exists {
			fmt.Println(id)
		}

		residents[id] = &Resident{
			residentID:     id,
			firstname:      record[1],
			lastname:       record[2],
			rol:            parseRol(record[3]),
			matchedProgram: "",
		}
	}

	return residents, nil
}

// reads a CSV file into a map of Program
func ReadProgramsCSV(filename string) (map[string]*Program, error) {

	// map to store programs by ID
	programs := make(map[string]*Program)

	file, err := os.Open(filename)
	if err != nil {
		return nil, fmt.Errorf("unable to open file: %w", err)
	}
	defer file.Close()

	reader := csv.NewReader(file)

	// Read all records
	records, err := reader.ReadAll()
	if err != nil {
		return nil, fmt.Errorf("error reading CSV: %w", err)
	}

	// Skip header if present (assuming it is)
	for i, record := range records {
		if i == 0 && record[0] == "id" {
			continue
		}
		if len(record) < 4 {
			return nil, fmt.Errorf("invalid record at line %d: %v", i+1, record)
		}

		// Parse number of positions
		np, err := strconv.Atoi(record[2])
		if err != nil {
			return nil, fmt.Errorf("invalid number at line %d: %w", i+1, err)
		}

		programs[record[0]] = &Program{
			programID:  record[0],
			name:       record[1],
			nPositions: np,
			rol:        parseIntRol(record[3]),
		}

	}

	return programs, nil
}

func printResidents(residents map[int]*Resident) {

	var ids []int
	for id := range residents {
		ids = append(ids, id)
	}
	sort.Ints(ids)

	fmt.Println("\n--- Residents ---")

	for _, id := range ids {

		r := residents[id]
		fmt.Printf("ID: %d\n", r.residentID)
		fmt.Printf("Name: %s %s\n", r.firstname, r.lastname)
		fmt.Printf("ROL: %v\n", r.rol)

		if r.matchedProgram == "" {
			fmt.Printf("Matched Program: NOT_MATCHED\n")
		} else {
			fmt.Printf("Matched Program: %s\n", r.matchedProgram)
		}

		fmt.Printf("-----------------------\n")
	}
}

func printPrograms(programs map[string]*Program) {

	fmt.Println("\n--- Programs ---")

	var ids []string
	for id := range programs {
		ids = append(ids, id)
	}
	sort.Strings(ids)

	for _, id := range ids {

		p := programs[id]

		selectedCount := len(p.selectedResidents)
		remaining := p.nPositions - selectedCount

		fmt.Printf("Program ID: %s\n", p.programID)
		fmt.Printf("Name: %s\n", p.name)
		fmt.Printf("Quota: %d\n", p.nPositions)
		fmt.Printf("ROL: %v\n", p.rol)

		if selectedCount == 0 {
			fmt.Printf("Matched Residents: NONE\n")
		} else {
			fmt.Printf("Matched Residents (%d): %v\n", selectedCount, p.selectedResidents)
		}

		fmt.Printf("Remaining Positions: %d\n", remaining)
		fmt.Println("-----------------------")
	}
}

func printStableMatch(residents map[int]*Resident, programs map[string]*Program) {

	outFile, _ := os.Create("stable_match_output.txt")
	defer outFile.Close()

	fmt.Printf("\n\nlastname,firstname,residentID,programID,name\n")
	fmt.Fprint(outFile, "lastname,firstname,residentID,programID,name\n")

	var residentList []*Resident
	for _, r := range residents {
		residentList = append(residentList, r)
	}

	sort.Slice(residentList, func(i, j int) bool {
		if residentList[i].lastname == residentList[j].lastname {
			return residentList[i].firstname < residentList[j].firstname
		}
		return residentList[i].lastname < residentList[j].lastname
	})

	unmatchedCount := 0

	for _, r := range residentList {

		if r.matchedProgram == "" {
			fmt.Printf("%s,%s,%d,XXX,NOT_MATCHED\n", r.lastname, r.firstname, r.residentID)
			fmt.Fprintf(outFile, "%s,%s,%d,XXX,NOT_MATCHED\n", r.lastname, r.firstname, r.residentID)
			unmatchedCount++
		} else {
			p := programs[r.matchedProgram]
			fmt.Printf("%s,%s,%d,%s,%s\n", r.lastname, r.firstname, r.residentID, p.programID, p.name)
			fmt.Fprintf(outFile, "%s,%s,%d,%s,%s\n", r.lastname, r.firstname, r.residentID, p.programID, p.name)
		}
	}

	totalRemaining := 0
	for _, p := range programs {
		totalRemaining += p.nPositions - len(p.selectedResidents)
	}

	fmt.Printf("\nNumber of unmatched residents: %d\n", unmatchedCount)
	fmt.Printf("Number of positions available: %d\n", totalRemaining)
	fmt.Fprintf(outFile, "\nNumber of unmatched residents: %d\n", unmatchedCount)
	fmt.Fprintf(outFile, "Number of positions available: %d", totalRemaining)
}

func offer(rid int, residents map[int]*Resident, programs map[string]*Program, wg *sync.WaitGroup) {

	wg.Add(1)
	defer wg.Done()

	r := residents[rid]

	if r.matchedProgram != "" {
		return
	}

	for _, pid := range r.rol {

		p := programs[pid]
		if p == nil {
			continue
		}

		accepted := evaluate(rid, pid, residents, programs, wg)
		if accepted {
			return
		}
	}
}

func evaluate(rid int, pid string, residents map[int]*Resident, programs map[string]*Program, wg *sync.WaitGroup) bool {

	r := residents[rid]
	p := programs[pid]

	rank := -1
	for i, id := range p.rol {
		if id == rid {
			rank = i
			break
		}
	}

	if rank == -1 {
		return false
	}

	if len(p.selectedResidents) < p.nPositions {
		p.selectedResidents = append(p.selectedResidents, rid)
		r.matchedProgram = pid
		return true
	}

	leastPreferredIndex := 0
	leastPreferredRank := p.rank[p.selectedResidents[0]]

	for i, selectedID := range p.selectedResidents {
		rank := p.rank[selectedID]
		if rank > leastPreferredRank {
			leastPreferredRank = rank
			leastPreferredIndex = i
		}
	}

	if p.rank[rid] < leastPreferredRank {
		displacedID := p.selectedResidents[leastPreferredIndex]
		residents[displacedID].matchedProgram = "N/A"
		p.selectedResidents[leastPreferredIndex] = rid
		r.matchedProgram = pid
		return true
	}

	return false
}

func main() {

	var (
		//residentPath string = "residentSmall.csv"
		//programPath  string = "programSmall.csv"

		//residentPath string = "residents4000.csv"
		//programPath  string = "programs4000.csv"

		residentPath string = "residentsLarge.csv"
		programPath  string = "programsLarge.csv"
	)

	residents, err := ReadResidentsCSV(residentPath)
	if err != nil {
		fmt.Println("Error:", err)
		return
	}

	for _, p := range residents {
		fmt.Printf("ID: %d, Name: %s %s, Rol: %v\n", p.residentID, p.firstname, p.lastname, p.rol)
	}

	fmt.Println("------------------------------------------------------------------------------------------------")

	programs, err := ReadProgramsCSV(programPath)
	if err != nil {
		fmt.Println("Error:", err)
		return
	}

	for _, p := range programs {
		fmt.Printf("ID: %s, Name: %s, Number of pos: %d, Number of applicants: %d\n", p.programID, p.name, p.nPositions, len(p.rol))
	}

	fmt.Println("------------------------------------------------------------------------------------------------")

	var wg sync.WaitGroup

	start := time.Now()
	// Run the McVitie-Wilson algorithm

	for id, _ := range residents {
		go offer(id, residents, programs, &wg)
	}

	wg.Wait()
	end := time.Now()

	printStableMatch(residents, programs)

	fmt.Printf("\nExecution time: %s\n", end.Sub(start))

}
