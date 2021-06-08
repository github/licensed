package test

import (
	"github.com/davecgh/go-spew/spew"
	ctx "github.com/gorilla/context"
	lru "github.com/hashicorp/golang-lru"
	"golang.org/x/net/http2/hpack"
	"test/internal/fakevendor/github.com/owner/repo"
	"test/pkg/world"
)

func main() {
	lru.New(1)
	ctx.Purge(0)
	_ = hpack.ErrInvalidHuffman
	i := 1
	spew.Dump(i)
	testpackage.HelloWorld()
	world.HelloWorld()
}
