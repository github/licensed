package test

import (
  lru "github.com/hashicorp/golang-lru"
  ctx "github.com/gorilla/context"
  "golang.org/x/net/http2/hpack"
  "github.com/davecgh/go-spew/spew"
)

func main() {
  lru.New(1)
  ctx.Purge(0)
  _ = hpack.ErrInvalidHuffman
  i := 1
  spew.Dump(i)
}
