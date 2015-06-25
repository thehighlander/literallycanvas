window.LC = window.LC ? {}


class LC.LiterallyCanvas

  constructor: (@canvas, @opts) ->
    LC.bindEvents(this, @canvas, @opts.keyboardShortcuts)

    bgColor = @opts.backgroundColor or 'transparent';
    # if typeof bgColor == "string"
    #   bgColor = if bgColor.killRGBA then bgColor.killRGBA() else bgColor

    bgColor = 'rgb(255, 255, 255)'

    @colors =
      primary: @opts.primaryColor or '#000'
      secondary: @opts.secondaryColor or '#fff'
      background: bgColor
    @canvas.style.backgroundColor = @colors.background

    @watermarkImage = @opts.watermarkImage
    if @watermarkImage and not @watermarkImage.complete
      @watermarkImage.onload = => @repaint(true, false)

    @singleBufferModeOn = @opts.singleBufferModeOn
    @historyOn = @opts.historyOn
    @viewMode = if @opts.viewMode then @opts.viewMode else "presenter"

    if not @singleBufferModeOn
      @buffer = document.createElement('canvas')
      @bufferCtx = @buffer.getContext('2d')

    @ctx = @canvas.getContext('2d')

    @backgroundShapes = []
    @shapes = []

    @undoStack = []
    @redoStack = []

    @isDragging = false
    @position = {x: 0, y: 0}
    @scale = 1.0
    @tool = undefined

    if @opts.preserveCanvasContents
      backgroundImage = new Image()
      backgroundImage.src = @canvas.toDataURL()
      backgroundImage.onload = => @repaint()
      @backgroundShapes.push(new LC.ImageShape(0, 0, backgroundImage))

    @backgroundShapes = @backgroundShapes.concat(@opts.backgroundShapes or [])

    if @opts.sizeToContainer
      LC.util.sizeToContainer(@canvas, => @repaint())

    @repaint()

  updateSize: =>
    @canvas.setAttribute('width', @canvas.clientWidth)
    @canvas.setAttribute('height', @canvas.clientHeight)
    @repaint()

  trigger: (name, data) ->
    details = detail: data
    myEvent = null

    try
      myEvent = new CustomEvent(name, details)
    catch err
      myEvent = null
      KAPx.console.warn(err.message)
      KAPx.console.warn("unable to create CustomEvent")

    if not myEvent
      try
        myEvent = document.createEvent("CustomEvent")
        myEvent.initCustomEvent(name, false, false, details)
        KAPx.console.warn("CustomEvent created IE9+ style")
      catch err
        myEvent = null
        KAPx.console.error(err.message)
        KAPx.console.error("unable to create CustomEvent IE9+ style.")
    
    @canvas.dispatchEvent(myEvent)

  on: (name, fn) ->
    @canvas.addEventListener name, (e) ->
      fn e.detail

  clientCoordsToDrawingCoords: (x, y) ->
    x: (x - @position.x) / @scale,
    y: (y - @position.y) / @scale,

  drawingCoordsToClientCoords: (x, y) ->
    x: x * @scale + @position.x,
    y: y * @scale + @position.y

  setTool: (tool) ->
    @tool = tool
    @trigger('toolChange', {tool})

  begin: (x, y) ->
    if @viewMode != "viewOnly"
      newPos = @clientCoordsToDrawingCoords(x, y)
      if @tool
        @tool.begin newPos.x, newPos.y, this
        @isDragging = true
        @trigger("drawStart", {tool: @tool})

  continue: (x, y) ->
    if @viewMode != "viewOnly"
      newPos = @clientCoordsToDrawingCoords(x, y)
      if @isDragging && @tool
        @tool.continue newPos.x, newPos.y, this
        @trigger("drawContinue", {tool: @tool})

  end: (x, y) ->
    if @viewMode != "viewOnly"
      newPos = @clientCoordsToDrawingCoords(x, y)
      if @isDragging && @tool
        @tool.end newPos.x, newPos.y, this
        @isDragging = false
        @trigger("drawEnd", {tool: @tool})

  setColor: (name, color) ->
    @colors[name] = color
    # if typeof @colors.background == "string" and @colors.killRGBA
    #     @canvas.style.backgroundColor = @colors.background.killRGBA()
    # else
    #     @canvas.style.backgroundColor = @colors.background
    @canvas.style.backgroundColor = 'rgb(255, 255, 255)'

    @trigger "#{name}ColorChange", @colors[name]
    @repaint()

  getColor: (name) -> @colors[name]

  saveShape: (shape) ->
    @execute(new LC.AddShapeAction(this, shape))
    @trigger('shapeSave', {shape: shape})
    @trigger('drawingChange', {shape: shape})

  removeShapes: (typeToRemove, repaint=false) ->
    newShapes = []
    newShapes.push(keeper) for keeper in @shapes when not (keeper instanceof typeToRemove)
    @execute(new LC.ClearAction(@, @shapes, newShapes))
    # NOTE: this method exists only to support the pointer...
    # maybe i should make a pointer collection instead of using @shapes... If you
    # add repaint back in, it will make PointerTool behave erratically.
    # if repaint
    #   @trigger('drawingChange', {})

  numShapes: -> @shapes.length

  pan: (x, y) ->
    # Subtract because we are moving the viewport
    @position.x = @position.x - x
    @position.y = @position.y - y
    @trigger('pan', {x: @position.x, y: @position.y})

  zoom: (factor) ->
    oldScale = @scale
    @scale = @scale + factor
    @scale = Math.max(@scale, 0.6)
    @scale = Math.min(@scale, 4.0)
    @scale = Math.round(@scale * 100) / 100

    @position.x = LC.scalePositionScalar(
      @position.x, @canvas.width, oldScale, @scale)
    @position.y = LC.scalePositionScalar(
      @position.y, @canvas.height, oldScale, @scale)

    @repaint()
    @trigger('zoom', {oldScale: oldScale, newScale: @scale})

  # Repaints the canvas.
  # If dirty is true then all saved shapes are completely redrawn,
  # otherwise the back buffer is simply copied to the screen as is.
  # If drawBackground is true, the background is rendered as a solid
  # color, otherwise it is left transparent.
  repaint: (dirty = true, drawBackground = false) ->
    retryCallback = => @repaint(true)
    
    if not @singleBufferModeOn
      if dirty
        # use double buffering to render offscreen and swap
        @buffer.width = @canvas.width
        @buffer.height = @canvas.height
        @bufferCtx.clearRect(0, 0, @buffer.width, @buffer.height)
        if drawBackground
          @bufferCtx.fillStyle = @colors.background
          @bufferCtx.fillRect(0, 0, @buffer.width, @buffer.height)
        if @watermarkImage
          @bufferCtx.drawImage(
            @watermarkImage,
            @canvas.width / 2 - @watermarkImage.width / 2,
            @canvas.height / 2 - @watermarkImage.height / 2,
          )
        @draw(@backgroundShapes, @bufferCtx, retryCallback)
        @draw(@shapes, @bufferCtx, retryCallback)
      @ctx.clearRect(0, 0, @canvas.width, @canvas.height)      
      if @canvas.width > 0 and @canvas.height > 0
        @ctx.drawImage @buffer, 0, 0
    else
      # render directly to canvas element. will result in artifacts while drawing, but
      # improves performance dramatically for consuming drawings in IE8.
      @ctx.clearRect(0, 0, @canvas.width, @canvas.height)
      @draw(@backgroundShapes, @ctx, retryCallback)
      @draw(@shapes, @ctx, retryCallback)

    @trigger('repaint', null)

  # Redraws the back buffer to the screen in its current state
  # then draws the given shape translated and scaled on top of that.
  # This is used for updating a shape while it is being drawn
  # without doing a full repaint.
  # The context is restored to its original state before returning.
  update: (shape) ->
    @repaint(false)
    @transformed =>
      shape.update(@ctx)
    , @ctx

  # Draws the given shapes translated and scaled to the given context.
  # The context is restored to its original state before returning.
  draw: (shapes, ctx, retryCallback) ->
    return unless shapes.length
    drawShapes = =>
      for shape in shapes
        shape.draw(ctx, retryCallback)
    @transformed(drawShapes, ctx)

  # Executes the given function after translating and scaling the context.
  # The context is restored to its original state before returning.
  transformed: (fn, ctx) ->
    ctx.save()
    ctx.translate @position.x, @position.y
    ctx.scale @scale, @scale
    fn()
    ctx.restore()

  clear: (suppressChangeEvent=false) ->
    oldShapes = @shapes
    newShapes = []
    @execute(new LC.ClearAction(this, oldShapes, newShapes))
    @repaint()
    @trigger('clear', null)
    if not suppressChangeEvent
      @trigger('drawingChange', {})

  execute: (action) ->
    if @historyOn
      @undoStack.push(new LC.AddShapeAction(action.lc, action.shape))
    action.do()
    @redoStack = []

  undo: ->
    return unless @undoStack.length
    action = @undoStack.pop()
    action.undo()
    @redoStack.push(action)
    @trigger('undo', {action})
    @trigger('drawingChange', {})

  redo: ->
    return unless @redoStack.length
    action = @redoStack.pop()
    if @historyOn
      @undoStack.push(action)
    action.do()
    @trigger('redo', {action})
    @trigger('drawingChange', {})

  canUndo: -> !!@undoStack.length
  canRedo: -> !!@redoStack.length

  getPixel: (x, y) ->
    p = @drawingCoordsToClientCoords x, y
    pixel = @ctx.getImageData(p.x, p.y, 1, 1).data
    if pixel[3]
      "rgb(#{pixel[0]}, #{pixel[1]}, #{pixel[2]})"
    else
      null

  canvasForExport: ->
    @repaint(true, true)
    @canvas

  canvasWithBackground: (backgroundImageOrCanvas) ->
    @repaint(true, true)
    LC.util.combineCanvases(backgroundImageOrCanvas, @canvasForExport())

  getSnapshot: -> {shapes: (shape.toJSON() for shape in @shapes), @colors}
  getSnapshotJSON: -> JSON.stringify(@getSnapshot())

  loadSnapshot: (snapshot) ->
    return unless snapshot

    for k in ['primary', 'secondary', 'background']
      @setColor(k, snapshot.colors[k])

    shapeAction = new LC.AddShapeAction(this, null)

    @shapes = []
    for shapeRepr in snapshot.shapes
      if shapeRepr.className of LC
        shape = LC[shapeRepr.className].fromJSON(this, shapeRepr.data)
        if shape
          shapeAction.set(this, shape)
          @execute(shapeAction)
    @repaint(true)
    if not @historyOn
      @shapes = []

  loadSnapshotJSON: (str) ->
    @loadSnapshot(JSON.parse(str))


# maybe add checks to these in the future to make sure you never double-undo or
# double-redo
class LC.ClearAction

  constructor: (@lc, @oldShapes, @newShapes) ->

  do: ->
    @lc.shapes = @newShapes
    @lc.repaint()

  undo: ->
    @lc.shapes = @oldShapes
    @lc.repaint()


class LC.AddShapeAction

  constructor: (@lc, @shape) ->

  set: (@lc, @shape) ->

  do: ->
    @ix = @lc.shapes.length
    @lc.shapes.push(@shape)
    @lc.repaint()

  undo: ->
    @lc.shapes.pop(@ix)
    @lc.repaint()
