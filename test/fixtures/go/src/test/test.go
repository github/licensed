package test

import (
  lru "github.com/hashicorp/golang-lru"
  ctx "github.com/gorilla/context"
  "golang.org/x/net/http2/hpack"
)

func main() { 
  lru.New(1)
  ctx.Purge(0)
  _ = hpack.ErrInvalidHuffman
}
