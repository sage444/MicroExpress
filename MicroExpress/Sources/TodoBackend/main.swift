// File: main.swift - Add to existing file
let app = Express()

#if false
  fs.readFile("/etc/passwd") { err, data in
    guard let data = data else { return print("Failed:", err as Any) }
    print("Read passwd:", data)
  }
#endif

// Reusable middleware up here
app.use(querystring,
        cors(allowOrigin: "*"))

// Logging
app.use { req, res, next in
  print("\(req.header.method):", req.header.uri)
  next() // continue processing
}

app.get("/todos") { _, res, _ in
  res.render("Todolist", [ "title": "DoIt!", "todos": todos ])
}

app.get("/todomvc") { _, res, _ in
  // send JSON to the browser
  res.json(todos)
}

app.get("/moo") { req, res, next in
  res.send("Muhhh")
}

app.get { req, res, _ in
  // `param` is provided by querystring
  let text = req.param("text")
          ?? "Schwifty"
  res.send("Hello, \(text) world!")
}

// start server
app.listen(1337)
