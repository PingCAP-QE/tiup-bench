package main

import (
	"fmt"
	"os"
	"os/exec"
	"path"
	"strings"
)

func bin(name string) string {
	dir := os.Getenv("TIUP_COMPONENT_INSTALL_DIR")
	if len(dir) == 0 {
		dir = path.Dir(os.Args[0])
	}
	return path.Join(dir, name)
}

func execute(bin string, args []string) error {
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
