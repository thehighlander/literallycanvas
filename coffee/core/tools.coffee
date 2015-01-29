class LC.Tool

  # called when the user starts dragging
  begin: (x, y, lc) ->

  # called when the user moves while dragging
  continue: (x, y, lc) ->

  # called when the user finishes dragging
  end: (x, y, lc) ->


class LC.StrokeTool extends LC.Tool

  constructor: -> @strokeWidth = 5

  setStrokeWidth: (strokeWidth) ->
    @strokeWidth = strokeWidth
    @tool.strokeWidth = 15
    this.$el.find("input[type=range]").val(@tool.strokeWidth)
    this.$el.find(".brush-width-val").html("(" + @tool.strokeWidth + " px)")


class LC.RectangleTool extends LC.StrokeTool

  begin: (x, y, lc) ->
    @currentShape = new LC.Rectangle(
      x, y, @strokeWidth, lc.getColor('primary'), lc.getColor('secondary'))

  continue: (x, y, lc) ->
    @currentShape.width = x - @currentShape.x
    @currentShape.height = y - @currentShape.y
    lc.update(@currentShape)

  end: (x, y, lc) ->
    lc.saveShape(@currentShape)
    

class LC.LineTool extends LC.StrokeTool

  begin: (x, y, lc) ->
    @currentShape = new LC.Line(
      x, y, x, y, @strokeWidth, lc.getColor('primary'))

  continue: (x, y, lc) ->
    @currentShape.x2 = x
    @currentShape.y2 = y
    lc.update(@currentShape)

  end: (x, y, lc) ->
    lc.saveShape(@currentShape)


class LC.HighlighterTool extends LC.StrokeTool

  begin: (x, y, lc) ->
    @currentShape = new LC.Highlight(
      x, y, x, y, @strokeWidth, 'rgba(255, 255, 0, 0.50)')

  continue: (x, y, lc) ->
    @currentShape.x2 = x
    @currentShape.y2 = y
    lc.update(@currentShape)

  end: (x, y, lc) ->
    lc.saveShape(@currentShape)
   

class LC.Pencil extends LC.StrokeTool

  begin: (x, y, lc) ->
    @lastPointAdded = Date.now()
    @color = lc.getColor('primary')
    @currentShape = @makeShape()
    @currentShape.addPoint(@makePoint(x, y, lc))

  continue: (x, y, lc) ->
    # rate limit the Pencil tool to reduce bandwidth consumed
    if (Date.now() - @lastPointAdded) > 30
      @currentShape.addPoint(@makePoint(x, y, lc))
      @lastPointAdded = Date.now()

    lc.update(@currentShape)

  end: (x, y, lc) ->
    lc.saveShape(@currentShape)
    @currentShape = undefined
    @lastPointAdded = undefined

  makePoint: (x, y, lc) -> new LC.Point(x, y, @strokeWidth, @color)
  makeShape: -> new LC.LinePathShape(this)


class LC.Eraser extends LC.Pencil

  constructor: () ->
    @strokeWidth = 10

  makePoint: (x, y, lc) -> new LC.Point(x, y, @strokeWidth, '#000')
  makeShape: -> new LC.EraseLinePathShape(this)


class LC.Pan extends LC.Tool

  begin: (x, y, lc) -> @start = {x, y}

  continue: (x, y, lc) ->
    lc.pan @start.x - x, @start.y - y
    lc.repaint()

  end: (x, y, lc) ->
    lc.repaint()


class LC.EyeDropper extends LC.Tool
    
  readColor: (x, y, lc) ->
    newColor = lc.getPixel(x, y)
    lc.setColor('primary', newColor or lc.getColor('background'))

  begin: (x, y, lc) ->
    @readColor(x, y, lc)

  continue: (x, y, lc) ->
    @readColor(x, y, lc)


class LC.TextTool extends LC.Tool

  constructor: (@text = '', @font = 'bold 18px sans-serif') ->

  setText:(text) ->
    @text = text

  begin:(x, y, lc) ->
    @color = lc.getColor('primary')
    @currentShape = new LC.TextShape(x, y, @text, @color, @font)

  continue:(x, y, lc) ->
    @currentShape.x = x
    @currentShape.y = y
    lc.update(@currentShape)

  end:(x, y, lc) ->
    lc.saveShape(@currentShape)


class LC.EllipseTool extends LC.StrokeTool
  @root = "corner"

  begin: (x, y, lc) ->
    @currentShape = new LC.Ellipse(
      x, y, 20, 20, @strokeWidth, lc.getColor('primary'), lc.getColor('secondary'), @root)

  continue: (x, y, lc) ->
    @currentShape.width = x - @currentShape.x
    @currentShape.height = y - @currentShape.y

    lc.update(@currentShape)

  end: (x, y, lc) ->
    lc.saveShape(@currentShape)


class LC.HighlighterTool extends LC.StrokeTool

  begin: (x, y, lc) ->
    @currentShape = new LC.Highlight(
      x, y, x, y, @strokeWidth, 'rgba(255, 255, 0, 0.50)')

  continue: (x, y, lc) ->
    @currentShape.x2 = x
    @currentShape.y2 = y
    lc.update(@currentShape)

  end: (x, y, lc) ->
    lc.saveShape(@currentShape)


class LC.CheckmarkTool extends LC.StrokeTool

  begin: (x, y, lc) ->
    @currentShape = new LC.Checkmark(
      x, y, 20, 30, @strokeWidth, lc.getColor('primary'))

  continue: (x, y, lc) ->
    newX = x - @currentShape.x
    newY = y - @currentShape.y
    @currentShape.w = @currentShape.w = if newX > 20 then newX else 20
    @currentShape.h = @currentShape.h = if newY > 20 then newY else 20


    lc.update(@currentShape)

  end: (x, y, lc) ->
    lc.saveShape(@currentShape)


class LC.ArrowTool extends LC.StrokeTool

  begin: (x, y, lc) ->
    @currentShape = new LC.Arrow(
      x, y, 40, 30, @strokeWidth, lc.getColor('primary'))

  continue: (x, y, lc) ->
    @currentShape.w = x - @currentShape.x
    @currentShape.h = y - @currentShape.y
    lc.update(@currentShape)

  end: (x, y, lc) ->
    lc.saveShape(@currentShape)


class LC.StarTool extends LC.StrokeTool

  begin: (x, y, lc) ->
    @currentShape = new LC.Star(
      x, y, 30, 30, @strokeWidth, lc.getColor('primary'), lc.getColor('secondary'))

  continue: (x, y, lc) -># the pointer is fixed to square dimensions per biz requirement
    newSize = x - @currentShape.x
    @currentShape.h = @currentShape.w = if newSize > 30 then newSize else 30

    lc.update(@currentShape)

  end: (x, y, lc) ->
    lc.saveShape(@currentShape)


class LC.PointerTool extends LC.StrokeTool

  begin: (x, y, lc) ->
    lc.removeShapes(LC.Pointer)

    @currentShape = new LC.Pointer(
      x, y, 64, 64, lc.getColor('primary'))

  continue: (x, y, lc) ->
    # the pointer is fixed to square dimensions per biz requirement
    newSize = x - @currentShape.x
    # when width goes negative, all hell breaks loose. also, helps enforce a min. pointer size.
    @currentShape.h = @currentShape.w = if newSize > 64 then newSize else 64
    lc.update(@currentShape)

  end: (x, y, lc) ->
    lc.saveShape(@currentShape)
