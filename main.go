package main

import (
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

func bin(name string) string {
	dir := os.Getenv("TIUP_COMPONENT_INSTALL_DIR")
	if len(dir) == 0 {
		dir = filepath.Dir(os.Args[0])
	}
	return filepath.Join(dir, name)
}

func execute(bin string, args []string) error {
	// Check if the binary is allowed.
	if bin != "go-ycsb" && bin != "go-tpc" {
		return errors.New("binary must be 'go-ycsb' or 'go-tpc'")
	}

	// Define forbidden characters.
	forbiddenChars := ";|&<>()$\\"

	// Function to check if a string contains any forbidden characters.
	containsForbiddenChars := func(s string) bool {
		for _, char := range forbiddenChars {
			if strings.ContainsRune(s, char) {
				return true
			}
		}
		return false
	}

	// Check if any of the arguments contain forbidden characters.
	for _, arg := range args {
		if containsForbiddenChars(arg) {
			return errors.New("arguments contain forbidden characters")
		}
	}

	cmd := exec.Command(bin, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	return cmd.Run()
}

func run(args []string) error {
	bench := args[0]
	switch bench {
	case "ch", "rawsql", "tpcc", "tpch":
		return execute(bin("go-tpc"), append([]string{bench}, args[1:]...))
	case "ycsb":
		return execute(bin("go-ycsb"), args[1:])
	default:
		kind := "bench command"
		if strings.HasPrefix(bench, "-") {
			kind = "flags"
		}
		return fmt.Errorf("unknown %s: %s", kind, bench)
	}
}

func help() {
	msg := `Usage: tiup bench {ch/rawsql/tpcc/tpch/ycsb} [flags]`
	if len(os.Getenv("TIUP_COMPONENT_INSTALL_DIR")) == 0 {
		msg = strings.Replace(msg, "tiup bench", os.Args[0], 1)
	}
	fmt.Println(msg)
}

func main() {
	if len(os.Args) == 1 || os.Args[1] == "-h" || os.Args[1] == "--help" {
		help()
		return
	}
	if err := run(os.Args[1:]); err != nil {
		if execErr, ok := err.(*exec.ExitError); ok {
			os.Exit(execErr.ExitCode())
		}
		help()
		fmt.Fprintln(os.Stderr, err.Error())
		os.Exit(1)
	}
}
