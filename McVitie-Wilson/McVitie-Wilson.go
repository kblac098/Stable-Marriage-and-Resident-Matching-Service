package main

import (
	"fmt"
	"os"
	"sync"
	"time"
)

type Resident struct {
	residentID     int
	firstname      string
	lastname       string
	rol            []string
	matchedProgram string
}

type Program struct {
	programID         string
	name              string
	nPositions        int
	rol               []int
	selectedResidents []int
}

func offer() {
	return
}

func evaluate() {
	return
}

func loadResidents(path string, wg *sync.WaitGroup) {
	defer wg.Done()

	file, err := os.Open(path)
	if err != nil {
		fmt.Printf("Error: %s could not be loaded. %s\n", path, err)
		return
	}
	defer file.Close()

	fmt.Printf("\n%s loaded successfully\n", path)
}

func loadPrograms(path string, wg *sync.WaitGroup) {
	defer wg.Done()
	fmt.Printf("\n%s loaded successfully\n", path)
}

func McVitie_Wilson() {
	offer()
	evaluate()
}

func main() {

	var (
		resident_path string = "residentSmall.csv"
		program_path  string = "programSmall.csv"
	)

	start := time.Now()

	var wg sync.WaitGroup
	wg.Add(2)

	go loadResidents(resident_path, &wg)
	go loadPrograms(program_path, &wg)
	wg.Wait()

	McVitie_Wilson()

	end := time.Now()
	fmt.Printf("\nExecution time: %s\n", end.Sub(start))
}
