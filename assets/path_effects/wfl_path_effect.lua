type MyPathEffect = {
  context: Context,
}

function init(self: MyPathEffect, context: Context): boolean
  self.context = context
  return true
end

function update(self: MyPathEffect, inPath: PathData): PathData
  local path = Path.new()
  return path
end

function advance(self: MyPathEffect, seconds: number): boolean
  return true
end

-- Return a factory function that Rive uses to build the Path Effect instance.
return function(): PathEffect<MyPathEffect>
  return {
    init = init,
    update = update,
    advance = advance,
    context = late(),
  }
end
