// mayhem/kat/main.go — dynamically-linked known-answer probe for the App Engine
// remote_api wire codec. `import "C"` (cgo) forces a DYNAMICALLY LINKED binary so
// the LD_PRELOAD sabotage shim used by the gate's anti-reward-hacking check can
// neuter it (a statically-linked Go binary would be immune, giving a false-green
// oracle — exactly the trap netnew §4 warns about with `go test` alone).
//
// It imports the build-time-staged package (created by mayhem/build.sh at
// _mayhem_harness/apiparse) and runs KATRoundTrip(), which marshals+decodes a
// fixed remote_api.Response through the real protobuf parser, then prints the
// decoded fields in a fixed, greppable format for mayhem/test.sh to assert.
package main

// #include <stdint.h>
import "C"

import (
	"fmt"
	"os"

	apiparse "google.golang.org/appengine/_mayhem_harness/apiparse"
)

func main() {
	kat, err := apiparse.KATRoundTrip()
	if err != nil {
		fmt.Fprintf(os.Stderr, "KAT error: %v\n", err)
		os.Exit(1)
	}
	fmt.Printf("KAT_APPCODE=%d\n", kat.AppCode)
	fmt.Printf("KAT_APPDETAIL=%s\n", kat.AppDetail)
	fmt.Printf("KAT_RPCCODE=%d\n", kat.RpcCode)
	fmt.Printf("KAT_RPCDETAIL=%s\n", kat.RpcDetail)
	fmt.Printf("KAT_RESP=%s\n", kat.Resp)
	fmt.Printf("KAT_WIRELEN=%d\n", kat.WireLen)
}
