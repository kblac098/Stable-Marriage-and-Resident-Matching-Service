package main

import (
	"fmt"
	"sync"
	"time"
)

func offer() {
	fmt.Printf("offer_single")
}

func evaluate() {
	fmt.Printf("evaluate_single-thread")
}

func McVitie_Wilson_Single_Thread() {
	offer()
	evaluate()
}

func main() {
	start := time.Now()

	var wg sync.WaitGroup

	McVitie_Wilson_Single_Thread()
}
