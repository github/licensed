package test

import (
  lru "github.com/hashicorp/golang-lru"
  ctx "github.com/gorilla/context"
)

func main() { 
  lru.New(1)
  ctx.Purge(0)
}
