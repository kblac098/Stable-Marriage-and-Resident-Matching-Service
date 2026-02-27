package main

import (
	"encoding/csv"
	"fmt"
	"os"
	"sort"
	"strconv"
	"strings"

	"sync" //remove for single-threaded version
	"time"
)

type Resident struct {
	residentID     int
	firstname      string
	lastname       string
	rol            []string
	matchedProgram string
	mu             sync.Mutex //remove for single-threaded version
}

type Program struct {
	programID         string
	name              string
	nPositions        int
	rol               []int
	rank              map[int]int
	selectedResidents []int
	mu                sync.Mutex //remove for single-threaded version
}

func parseRol(s string) []string {
	s = strings.Trim(s, "[] ")
	if s == "" {
		return []string{}
	}
	parts := strings.Split(s, ",")
	for i := range parts {
		parts[i] = strings.TrimSpace(parts[i])
	}
	return parts
}

func parseIntRol(s string) []int {
	s = strings.Trim(s, "[] ")
	if s == "" {
		return []int{}
	}
	parts := strings.Split(s, ",")
	var result []int
	for _, p := range parts {
		val, _ := strconv.Atoi(strings.TrimSpace(p))
		result = append(result, val)
	}
	return result
}

func ReadResidentsCSV(filename string) (map[int]*Resident, error) {
	residents := make(map[int]*Resident)

	file, err := os.Open(filename)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	reader := csv.NewReader(file)
	records, _ := reader.ReadAll()

	for i, record := range records {
		if i == 0 && record[0] == "id" {
			continue
		}
		id, _ := strconv.Atoi(record[0])
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

func ReadProgramsCSV(filename string) (map[string]*Program, error) {
	programs := make(map[string]*Program)

	file, err := os.Open(filename)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	reader := csv.NewReader(file)
	records, _ := reader.ReadAll()

	for i, record := range records {
		if i == 0 && record[0] == "id" {
			continue
		}
		np, _ := strconv.Atoi(record[2])
		rol := parseIntRol(record[3])

		rankMap := make(map[int]int)
		for i, rid := range rol {
			rankMap[rid] = i
		}

		programs[record[0]] = &Program{
			programID:  record[0],
			name:       record[1],
			nPositions: np,
			rol:        rol,
			rank:       rankMap,
		}
	}
	return programs, nil
}

var globalWG sync.WaitGroup //remove for single-threaded version

func offer(rid int, residents map[int]*Resident, programs map[string]*Program) {
	defer globalWG.Done() //remove for single-threaded version

	r := residents[rid]

	r.mu.Lock() //remove for single-threaded version
	if r.matchedProgram != "" {
		r.mu.Unlock() //remove for single-threaded version
		return
	}
	r.mu.Unlock() //remove for single-threaded version

	for _, pid := range r.rol {
		if evaluate(rid, pid, residents, programs) {
			return
		}
	}
}

func evaluate(rid int, pid string, residents map[int]*Resident, programs map[string]*Program) bool {

	p := programs[pid]
	r := residents[rid]

	p.mu.Lock()         //remove for single-threaded version
	defer p.mu.Unlock() //remove for single-threaded version

	rank, ok := p.rank[rid]
	if !ok {
		return false
	}

	if len(p.selectedResidents) < p.nPositions {
		p.selectedResidents = append(p.selectedResidents, rid)
		r.matchedProgram = pid
		return true
	}

	leastIndex := 0
	leastRank := p.rank[p.selectedResidents[0]]

	for i, sid := range p.selectedResidents {
		if p.rank[sid] > leastRank {
			leastRank = p.rank[sid]
			leastIndex = i
		}
	}

	if rank < leastRank {

		displacedID := p.selectedResidents[leastIndex]
		p.selectedResidents[leastIndex] = rid

		r.matchedProgram = pid

		displaced := residents[displacedID]
		displaced.matchedProgram = ""

		globalWG.Add(1) //remove for single-threaded version
		//remove go statement for single-threaded version
		go offer(displacedID, residents, programs)
		//offer(displacedID, residents, programs)

		return true
	}

	return false
}

func printStableMatch(residents map[int]*Resident, programs map[string]*Program, elapsed time.Duration) {

	outFile, _ := os.Create("stable_match_output.txt")
	defer outFile.Close()

	fmt.Fprint(outFile, "lastname,firstname,residentID,programID,name\n")

	fmt.Println("\nlastname,firstname,residentID,programID,name")

	var list []*Resident
	for _, r := range residents {
		list = append(list, r)
	}

	sort.Slice(list, func(i, j int) bool {
		if list[i].lastname == list[j].lastname {
			return list[i].firstname < list[j].firstname
		}
		return list[i].lastname < list[j].lastname
	})

	unmatched := 0

	for _, r := range list {
		if r.matchedProgram == "" {
			fmt.Printf("%s,%s,%d,XXX,NOT_MATCHED\n", r.lastname, r.firstname, r.residentID)
			fmt.Fprintf(outFile, "%s,%s,%d,XXX,NOT_MATCHED\n", r.lastname, r.firstname, r.residentID)
			unmatched++
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

	fmt.Fprintf(outFile, "\nNumber of unmatched residents: %d\n", unmatched)
	fmt.Fprintf(outFile, "Number of positions available: %d", totalRemaining)
	fmt.Fprintf(outFile, "\n\nExecution time: %v", elapsed)

	fmt.Printf("\nNumber of unmatched residents: %d\n", unmatched)
	fmt.Printf("Number of positions available: %d\n", totalRemaining)
	fmt.Printf("\nExecution time: %v\n", elapsed)
}

func main() {

	// residentPath := "residentSmall.csv"
	// programPath := "programSmall.csv"

	// residentPath := "residents4000.csv"
	// programPath := "programs4000.csv"

	residentPath := "residentsLarge.csv"
	programPath := "programsLarge.csv"

	residents, _ := ReadResidentsCSV(residentPath)
	programs, _ := ReadProgramsCSV(programPath)

	start := time.Now()

	var ids []int
	for id := range residents {
		ids = append(ids, id)
	}
	sort.Ints(ids)

	for _, id := range ids {

		globalWG.Add(1) //remove for single-threaded version
		//remove go statement for single-threaded version
		go offer(id, residents, programs)
		//offer(id, residents, programs)
	}

	globalWG.Wait() //remove for single-threaded version

	end := time.Now()

	printStableMatch(residents, programs, end.Sub(start))
}
