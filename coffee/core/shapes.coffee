window.LC = window.LC ? {}


class LC.Shape

  className: null

  # Redraw the entire shape
  draw: (ctx) ->

  # Draw just the most recent portion of the shape if applicable
  update: (ctx) ->
    @draw(ctx)

  toJSON: -> {className: @className, data: @jsonContent()}
  jsonContent: -> raise "not implemented"
  @fromJSON: (lc, data) -> raise "not implemented"


class LC.ImageShape extends LC.Shape

  className: 'ImageShape'

  constructor: (@x, @y, @image, @w, @h) ->
  draw: (ctx, retryCallback) ->
    if @image
      if (@w && @w > 0) && (@h && @h > 0)
        ctx.drawImage(@image, @x, @y, @w, @h)
      else
        ctx.drawImage(@image, @x, @y)
    else
      @image.onload = retryCallback
  jsonContent: ->
    w = if @w then @w else 0
    h = if @h then @h else 0
    {@x, @y, imageSrc: @image.src, w, h}
  @fromJSON: (lc, data) ->
    img = new Image()
    img.src = data.imageSrc
    img.onload = () -> lc.repaint()
    i = new LC.ImageShape(data.x, data.y, img, data.w, data.h)


class LC.Rectangle extends LC.Shape

  className: 'Rectangle'

  constructor: (@x, @y, @strokeWidth, @strokeColor, @fillColor) ->
    @width = 0
    @height = 0

  draw: (ctx) ->
    ctx.fillStyle = @fillColor
    ctx.fillRect(@x, @y, @width, @height)
    ctx.lineWidth = @strokeWidth
    ctx.strokeStyle = @strokeColor
    ctx.strokeRect(@x, @y, @width, @height)

  jsonContent: ->
    {@x, @y, @width, @height, @strokeWidth, @strokeColor, @fillColor}

  @fromJSON: (lc, data) ->
    shape = new LC.Rectangle(
      data.x, data.y, data.strokeWidth, data.strokeColor, data.fillColor)
    shape.width = data.width
    shape.height = data.height
    shape


class LC.Line extends LC.Shape

  className: 'Line'

  constructor: (@x1, @y1, @x2, @y2, @strokeWidth, @color) ->

  draw: (ctx) ->
    ctx.lineWidth = @strokeWidth
    ctx.strokeStyle = @color
    ctx.lineCap = 'round'
    ctx.beginPath()
    ctx.moveTo(@x1, @y1)
    ctx.lineTo(@x2, @y2)
    ctx.stroke()

  jsonContent: ->
    {@x1, @y1, @x2, @y2, @strokeWidth, @color}

  @fromJSON: (lc, data) ->
    shape = new LC.Line(
      data.x1, data.y1, data.x2, data.y2, data.strokeWidth, data.color)
    shape


class LC.Highlight extends LC.Line

  className: 'Highlight'

  draw: (ctx) ->
    ctx.lineWidth = @strokeWidth
    ctx.strokeStyle = @color
    ctx.lineCap = 'square'
    ctx.beginPath()
    ctx.moveTo(@x1, @y1)
    ctx.lineTo(@x2, @y2)
    ctx.stroke()

  @fromJSON: (lc, data) ->
    shape = new LC.Highlight(
      data.x1, data.y1, data.x2, data.y2, data.strokeWidth, data.color)
    shape


class LC.LinePathShape extends LC.Shape

  className: 'LinePathShape'

  constructor: (_points = [], @order = 3, @tailSize = 3)->
    # The number of smoothed points generated for each point added
    @segmentSize = Math.pow(2, @order)

    # The number of points used to calculate the bspline to the newest point
    @sampleSize = @tailSize + 1

    @points = []
    for point in _points
      @addPoint(point)

  jsonContent: ->
    # TODO: make point storage more efficient
    {@order, @tailSize, @points}

  @fromJSON: (lc, data) ->
    points = (new LC.Point.fromJSON(lc, pointData) \
              for pointData in data.points)
    new LC.LinePathShape(points, data.order, data.tailSize)

  addPoint: (point) ->
    # Brush Variance Code
    #distance = LC.len(LC.diff(LC.util.last(@points), newPoint)) if @points.length
    #newPoint.size = newPoint.size + Math.sqrt(distance) if distance

    @points.push(point)

    if not @smoothedPoints or @points.length < @sampleSize
      @smoothedPoints = LC.bspline(@points, @order)
    else
      @tail = LC.util.last(
        LC.bspline(LC.util.last(@points, @sampleSize), @order),
                   @segmentSize * @tailSize)

      # Remove the last @tailSize - 1 segments from @smoothedPoints
      # then concat the tail. This is done because smoothed points
      # close to the end of the path will change as new points are
      # added.
      @smoothedPoints = @smoothedPoints.slice(
        0, @smoothedPoints.length - @segmentSize * (@tailSize - 1)
      ).concat(@tail)

  draw: (ctx) ->
    points = @smoothedPoints
    return unless points.length

    ctx.strokeStyle = points[0].color
    ctx.lineWidth = points[0].size
    ctx.lineCap = 'round'
    ctx.beginPath()
    ctx.moveTo(points[0].x, points[0].y)
    for point in points.slice(1)
      ctx.lineTo(point.x, point.y)
    ctx.stroke()

    # Polygonal Line Code
    #poly = LC.toPoly(@smoothedPoints)

    #_.each [fp, lp], (p) ->
    #  ctx.beginPath()
    #  ctx.fillStyle = p.color
    #  ctx.arc(p.x, p.y, p.size / 2, 0, Math.PI * 2)
    #  ctx.fill()
    #  ctx.closePath()

    #ctx.beginPath(poly[0].x, poly[0].y)
    #ctx.fillStyle = poly[0].color
    #_.each poly, (point) ->
    #  ctx.lineTo(point.x, point.y)
    #ctx.closePath()
    #ctx.fill()
    

class LC.EraseLinePathShape extends LC.LinePathShape

  className: 'EraseLinePathShape'

  draw: (ctx) ->
    ctx.save()
    ctx.globalCompositeOperation = "destination-out"
    super(ctx)
    ctx.restore()

  update: (ctx) ->
    ctx.save()
    ctx.globalCompositeOperation = "destination-out"
    super(ctx)
    ctx.restore()

  # same as LinePathShape
  @fromJSON: (lc, data) ->
    points = (new LC.Point.fromJSON(lc, pointData) \
              for pointData in data.points)
    new LC.EraseLinePathShape(points, data.order, data.tailSize)


class LC.Point

  className: 'Point'

  constructor: (@x, @y, @size, @color) ->
  lastPoint: -> this
  draw: (ctx) -> console.log 'draw point', @x, @y, @size, @color

  jsonContent: -> {@x, @y, @size, @color}
  @fromJSON: (lc, data) ->
    new LC.Point(data.x, data.y, data.size, data.color)


class LC.TextShape extends LC.Shape

  className: 'TextShape'

  constructor: (@x, @y, @text, @color, @font = '18px sans-serif;') ->
  draw: (ctx) -> 
    ctx.font  = @font
    ctx.fillStyle = @color
    ctx.fillText(@text, @x, @y)
  jsonContent: -> {@x, @y, @text, @color, @font}
  @fromJSON: (lc, data) ->
    new LC.TextShape(data.x, data.y, data.text, data.color, data.font)


class LC.Ellipse extends LC.Shape

  #todo: when HTML5 ellipse is better supported, switch to using that instead of calculating a "rough ellipse."
  # as of this note (02 May 14), ellipse only exists in Chrome & Opera. No Firefox or IE(hahahahaha) and no FlashCanvas polyfill.
  className: 'Ellipse'

  constructor: (@x, @y, @width, @height, @strokeWidth, @strokeColor, @fillColor, @root='corner') ->
  
  draw: (ctx) ->
    if @root=='center'
      @drawFromCenter(ctx)
    else
      @drawFromCorner(ctx)

  drawFromCenter: (ctx) ->
    ctx.save() # save state
    ctx.beginPath()
    ctx.translate(@x-@width, @y-@height)
    ctx.scale(@width, @height)
    ctx.arc(1, 1, 1, 0, 2 * Math.PI, false)
    ctx.restore() # restore to original state
    ctx.save()
    if @strokeColor 
      ctx.strokeStyle = @strokeColor
    if @fillColor 
      ctx.fillStyle = @fillColor
      ctx.fill()
    ctx.lineWidth = @strokeWidth
    ctx.stroke()
    ctx.restore()

  drawFromCorner: (ctx) ->
    kappa = .5522848
    ox = (@width / 2) * kappa   # control point offset horizontal
    oy = (@height / 2) * kappa  # control point offset vertical
    xe = @x + @width            # x-end
    ye = @y + @height           # y-end
    xm = @x + @width / 2        # x-middle
    ym = @y + @height / 2       # y-middle

    ctx.save();
    ctx.beginPath();
    ctx.moveTo(@x, ym);
    ctx.bezierCurveTo(@x, ym - oy, xm - ox, @y, xm, @y);
    ctx.bezierCurveTo(xm + ox, @y, xe, ym - oy, xe, ym);
    ctx.bezierCurveTo(xe, ym + oy, xm + ox, ye, xm, ye);
    ctx.bezierCurveTo(xm - ox, ye, @x, ym + oy, @x, ym);    
    if @strokeColor 
      ctx.strokeStyle = @strokeColor
    if @fillColor 
      ctx.fillStyle = @fillColor
      ctx.fill()
    ctx.lineWidth = @strokeWidth
    ctx.stroke();
    ctx.restore();

  jsonContent: ->
    {@x, @y, @width, @height, @strokeWidth, @strokeColor, @fillColor, @root}

  @fromJSON: (lc, data) ->
    shape = new LC.Ellipse(
      data.x, data.y, data.width, data.height, data.strokeWidth, data.strokeColor, data.fillColor, data.root)
    shape


class LC.Checkmark extends LC.Shape

  className: 'Checkmark'

  constructor: (@x, @y, @w, @h, @strokeWidth, @strokeColor) ->

  draw: (ctx) ->
    ctx.save() 
    @drawCheck(ctx, {x:@x, y:@y, w:@w, h:@h})
    ctx.restore() 

  drawCheck: (ctx, rect) ->
    checkStart = {
        "x": rect.x,
        "y": rect.y + (rect.h * (2/3))
    }
    checkPoint = {
        "x": rect.x + (rect.w * (1/3)),
        "y": rect.y + rect.h
    }
    checkEnd = {
        "x": rect.x + rect.w,
        "y": rect.y
    }
    
    ctx.beginPath()
    ctx.lineCap = 'square'
    ctx.fillStyle = @fillColor
    ctx.lineWidth = @strokeWidth
    ctx.strokeStyle = @strokeColor
    ctx.moveTo(checkStart.x, checkStart.y)
    ctx.lineTo(checkPoint.x, checkPoint.y)
    ctx.lineTo(checkEnd.x, checkEnd.y)
    ctx.stroke()

  jsonContent: ->
     {@x, @y, @w, @h, @strokeWidth, @strokeColor}

  @fromJSON: (lc, data) ->
    shape = new LC.Checkmark(
      data.x, data.y, data.w, data.h, data.strokeWidth, data.strokeColor)
    shape


class LC.Arrow extends LC.Shape
  #todo: modify arrow to be "line-based" so it can be any angle instead of horizontally fixed.
  # see: http://www.dbp-consulting.com/tutorials/canvas/CanvasArrow.html

  className: 'Arrow'

  constructor: (@x, @y, @w, @h, @strokeWidth, @strokeColor) ->

  draw: (ctx) ->    
    ctx.save() 
    @drawArrow(ctx, {x:@x, y:@y, w:@w, h:@h})
    ctx.restore() 

  drawArrow: (ctx, rect) ->
    arrowStart = {
        "x": rect.x,
        "y": rect.y + rect.h / 2
    }
    arrowPoint = {
        "x": rect.x + rect.w,
        "y": rect.y + rect.h / 2
    }

    # arbitrary 1/2 position for arrow tip
    endCapX = rect.x + (1 / 2) * rect.w

    ctx.lineWidth = @strokeWidth
    ctx.strokeStyle = @strokeColor
    ctx.lineCap = 'round'

    # draw the arrow body    
    ctx.beginPath()
    ctx.moveTo(arrowStart.x, arrowStart.y)
    ctx.lineTo(arrowPoint.x, arrowPoint.y)
    ctx.stroke()

    # draw head of arrow as a single line so the "tip" is drawn with a nice point.
    ctx.beginPath()
    ctx.lineCap = 'square'
    ctx.moveTo(endCapX, rect.y)
    ctx.lineTo(arrowPoint.x, arrowPoint.y)
    ctx.lineTo(endCapX, rect.y + rect.h)
    ctx.stroke()

  jsonContent: ->
     {@x, @y, @w, @h, @strokeWidth, @strokeColor}

  @fromJSON: (lc, data) ->
    shape = new LC.Arrow(
      data.x, data.y, data.w, data.h, data.strokeWidth, data.strokeColor)
    shape


class LC.Star extends LC.Shape

  className: 'Star'

  constructor: (@x, @y, @w, @h, @strokeWidth, @strokeColor, @fillColor) ->

  draw: (ctx) ->    
    @drawSimpleStar(ctx, {x:@x, y:@y, w:@w, h:@h})

  drawStar: (ctx, cx, cy, spikes, innerRad, outerRad) ->
    rot=Math.PI/2*3
    x=cx
    y=cy
    step=Math.PI/spikes
   
    ctx.save()
    ctx.translate(cx, cy) # translate & rotate to make the point straight up.
    ctx.rotate((Math.PI * 1 / spikes))
    ctx.translate(-cx, -cy)
    ctx.strokeStyle=@strokeColor
    ctx.fillStyle=@fillColor
    ctx.lineWidth=@strokeWidth
    ctx.beginPath()

    for num in [0..spikes]
      x=cx+Math.cos(rot)*innerRad
      y=cy+Math.sin(rot)*innerRad
      ctx.lineTo(x,y)
      rot+=step      
      x=cx+Math.cos(rot)*outerRad
      y=cy+Math.sin(rot)*outerRad
      ctx.lineTo(x,y)
      rot+=step

    ctx.lineTo(cx, cy-innerRad)
    ctx.stroke()
    ctx.closePath()  
    ctx.fill()
    ctx.restore() 

  drawSimpleStar: (ctx, rect) ->
    center = {
        x: rect.x + (rect.w / 2),
        y: rect.y + (rect.h / 2)
    }

    points = 5
    innerRad = rect.w / 5
    outerRad = rect.w / 2

    @drawStar(ctx, center.x, center.y, points, innerRad, outerRad)

  jsonContent: ->
     {@x, @y, @w, @h, @strokeWidth, @strokeColor, @fillColor}

  @fromJSON: (lc, data) ->
    shape = new LC.Star(
      data.x, data.y, data.w, data.h, data.strokeWidth, data.strokeColor, data.fillColor)
    shape


class LC.Pointer extends LC.Shape

  className: 'Pointer'

  constructor: (@x, @y, @w, @h, @fillColor) ->

  draw : (ctx) ->  
    # ctx.save()
    # gradient created at http://victorblog.com/html5-canvas-gradient-creator
    grd = ctx.createRadialGradient(@x, @y, 0.000, @x, @y, @h/2)   
    grd.addColorStop(0.289, @fillColor)
    grd.addColorStop(1.000, 'rgba(255, 255, 255, 0.000)')
    
    ctx.beginPath()
    ctx.arc(@x, @y, @h/2, 0, 2*Math.PI, false)    
    ctx.fillStyle = grd
    ctx.fill()
    # ctx.restore() 

  jsonContent: ->
     {@x, @y, @w, @h, @strokeWidth, @fillColor}

  @fromJSON: (lc, data) ->
    shape = new LC.Pointer(
      data.x, data.y, data.w, data.h, data.fillColor)
    shape

