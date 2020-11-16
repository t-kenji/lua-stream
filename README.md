# Streaming request handling module for Lua

## Features

- Implemented in pure Lua: works with 5.4

## Usage

The `stream.lua` file should be download into an `package.path` directory and required by it:

```lua
local stream = require('stream')
```

The module provides the following functions:

### stream.unix(path)

Create and bind a Unix Domain Socket.

```lua
local sock = stream.unix('/tmp/unix.sock')
```

### stream.accept(sock, accept)

Wait for server connect and call callback when accepted.

```lua
function accept(sock)
    -- Some processing.
end

stream.accept(sock, accept)
```

### stream.serve()

```lua
stream.serve()
```

## License

This module is free software; you can redistribute it and/or modify it under
the terms of the MIT license. See [LICENSE](LICENSE) for details.

