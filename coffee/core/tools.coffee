class LC.Tool

  # called when the user starts dragging
  begin: (x, y, lc) ->

  # called when the user moves while dragging
  continue: (x, y, lc) ->

  # called when the user finishes dragging
  end: (x, y, lc) ->


class LC.StrokeTool extends LC.Tool

  constructor: -> @strokeWidth = 5


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


class LC.EllipseTool extends LC.StrokeTool
  @root = "corner"

  begin: (x, y, lc) ->
    @currentShape = new LC.Ellipse(
      x, y, 0, 0, @strokeWidth, lc.getColor('primary'), lc.getColor('secondary'), @root)

  continue: (x, y, lc) ->
    @currentShape.width = x - @currentShape.x
    @currentShape.height = y - @currentShape.y
    lc.update(@currentShape)

  end: (x, y, lc) ->
    lc.saveShape(@currentShape)


class LC.StampTool extends LC.StrokeTool

  getCurrentStamp: () ->
    output = null

    switch @currentStamp
      when "arrowleft"
        output = @arrowLeftStamp
      when "arrowright"
        output = @arrowRightStamp
      when "checkmark"
        output = @checkmarkStamp
      when "star"
        output = @starStamp
      else
        output = @checkmarkStamp

    return output

  preloadImages: () ->
    @arrowLeftStamp = new Image()
    @arrowLeftStamp.src = "/content/img/literally/stamps/arrowleft.png"

    @arrowRightStamp = new Image()
    @arrowRightStamp.src = "/content/img/literally/stamps/arrowright.png"

    @starStamp = new Image()
    @starStamp.src = "/content/img/literally/stamps/star.png"

    @checkmarkStamp = new Image()
    @checkmarkStamp.src = "/content/img/literally/stamps/checkmark.png"

  constructor: () -> 
    @strokeWidth = 0
    @currentStamp = null;
    @preloadImages()

  begin: (x, y, lc) ->
    strokeColor = "rgba(255, 255, 255, 0.0)" # lc.getColor('primary')
    fillColor = "rgba(1, 1, 1, 0.25)" # lc.getColor('secondary')

    # use a rectangle to indicate the final size of the stamp (until i figure out how to resize stamp on the fly).
    # also, give 'em the transparent rectangle as guide if no tool was selected.
    @currentShape = new LC.Rectangle(x, y, @strokeWidth, strokeColor, fillColor)

  continue: (x, y, lc) ->
    @currentShape.width = x - @currentShape.x
    @currentShape.height = y - @currentShape.y
    
    lc.update(@currentShape)

  end: (x, y, lc) ->
    #todo: use stroke & fill from primary/secondary to draw shape.
    @img = @getCurrentStamp()

    # #do some swaperooni on the x/y values. if you draw anything but top left to bottom right 
    # of the rectangle, the ImageShape fails to draw correctly due to negative widths.
    if @currentShape.width < 0
      @currentShape.x = @currentShape.x + @currentShape.width
      @currentShape.width = Math.abs(@currentShape.width)

    if @currentShape.height < 0
      @currentShape.y = @currentShape.y + @currentShape.height
      @currentShape.height = Math.abs(@currentShape.height)

    @currentShape = new LC.ImageShape(@currentShape.x, @currentShape.y, @img, @currentShape.width, @currentShape.height)

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
    @color = lc.getColor('primary')
    @currentShape = @makeShape()
    @currentShape.addPoint(@makePoint(x, y, lc))

  continue: (x, y, lc) ->
    @currentShape.addPoint(@makePoint(x, y, lc))
    lc.update(@currentShape)

  end: (x, y, lc) ->
    lc.saveShape(@currentShape)
    @currentShape = undefined

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

