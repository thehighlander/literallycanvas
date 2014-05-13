class LC.Widget

  constructor: (@opts) ->

  # text to be shown in a hypothetical tooltip
  title: undefined

  # suffix of the CSS elements that are generated for this class.
  # specficially tool-{suffix} for the button, and tool-options-{suffix} for
  # the options container.
  cssSuffix: undefined

  # function that returns the HTML of the tool button's contents
  button: -> undefined

  # function that returns the HTML of the tool options
  options: -> undefined

  # called when the widget is selected
  select: (lc) ->


class LC.ToolWidget extends LC.Widget

  constructor: (@opts) ->
    @tool = @makeTool()

  select: (lc) ->
    if @prepareTool
      @prepareTool(lc)

    lc.setTool(@tool)

  makeTool: -> undefined


class LC.StrokeWidget extends LC.ToolWidget

  options: ->
    $el = $("<span class='brush-width-min'>1 px</span><input type='range' min='1' max='50' step='1' value='#{@tool.strokeWidth}'><span class='brush-width-max'>50 px</span><span class='brush-width-val'>(5 px)</span>")

    $input = $el.filter('input')
    if $input.size() == 0
      $input = $el.find('input')

    $brushWidthVal = $el.filter('.brush-width-val')
    if $brushWidthVal.size() == 0
      $brushWidthVal = $el.find('.brush-width-val')

    $input.change (e) =>
      @tool.strokeWidth = parseInt($(e.currentTarget).val(), 10)
      $brushWidthVal.html("(#{@tool.strokeWidth} px)")
    return $el


class LC.RectangleWidget extends LC.StrokeWidget

  title: 'Rectangle'
  cssSuffix: 'rectangle'
  button: -> "<img src='#{@opts.imageURLPrefix}/rectangle.png'>"
  makeTool: -> new LC.RectangleTool()


class LC.EllipseWidget extends LC.StrokeWidget

  title: 'Ellipse'
  cssSuffix: 'ellipse'
  button: -> "<img src='#{@opts.imageURLPrefix}/ellipse.png'>"
  makeTool: -> new LC.EllipseTool()
  options: ->
    # use the base class so I can get the slider for stroke thickness.
    @$el = LC.StrokeWidget.prototype.options.call(this)
    @$el = @$el.add("<div id='ellipseOptions' style='display: inline;'><div class='button' data-root='corner'><img width='18' height='18' src='#{@opts.imageURLPrefix}/ellipse-corner.png' alt='Draw ellipse from corner'></div><div class='button' data-root='center'><img width='18' height='18' src='#{@opts.imageURLPrefix}/ellipse-center.png' alt='Draw ellipse from center.'></div></div>")
    
    cornerButton = @$el.find('[data-root=corner]')
    cornerButton.click (e) => @selectButton(cornerButton)

    centerButton = @$el.find('[data-root=center]')
    centerButton.click (e) => @selectButton(centerButton)

    @$el

  selectButton: (t) ->
    @$el.find("#ellipseOptions .active").removeClass("active")
    t.addClass("active")
    @tool.root = t.attr("data-root")

class LC.HighlighterWidget extends LC.StrokeWidget

  title: 'Highlighter'
  cssSuffix: 'highlighter'
  button: -> "<img src='#{@opts.imageURLPrefix}/highlighter.png'>"
  makeTool: -> new LC.HighlighterTool()
  prepareTool: (lc) -> 
    # tool.strokeWidth = 40;
    # canvas.setColor("primary", "rgba(255, 255, 0, 0.50)");
    # $(".tool-options-highlighter input[type=range]").val(40)
    # $(".brush-width-val").html("(" +tool.strokeWidth + " px)");
    @tool.strokeWidth = 40
    lc.ctx.lineCap = "square"
    #lc.setColor("primary", "rgba(255, 255, 0, 0.50)")
    #lc.colors.primary = lc.getColor('primary')    
    this.$el.find("input[type=range]").val(@tool.strokeWidth)
    this.$el.find(".brush-width-val").html("(" + @tool.strokeWidth + " px)")
    

class LC.LineWidget extends LC.StrokeWidget

  title: 'Line'
  cssSuffix: 'line'
  button: -> "<img src='#{@opts.imageURLPrefix}/line.png'>"
  makeTool: -> new LC.LineTool()


class LC.PencilWidget extends LC.StrokeWidget

  title: "Pencil"
  cssSuffix: "pencil"
  button: -> "<img src='#{@opts.imageURLPrefix}/pencil.png'>"
  makeTool: -> new LC.Pencil()


class LC.EraserWidget extends LC.PencilWidget

  title: "Eraser"
  cssSuffix: "eraser"
  button: -> "<img src='#{@opts.imageURLPrefix}/eraser.png'>"
  makeTool: -> new LC.Eraser()


class LC.PanWidget extends LC.ToolWidget

  title: "Pan"
  cssSuffix: "pan"
  button: -> "<img src='#{@opts.imageURLPrefix}/pan.png'>"
  makeTool: -> new LC.Pan()


class LC.EyeDropperWidget extends LC.ToolWidget

  title: "Eyedropper"
  cssSuffix: "eye-dropper"
  button: -> "<img src='#{@opts.imageURLPrefix}/eyedropper.png'>"
  makeTool: -> new LC.EyeDropper()


class LC.TextWidget extends LC.ToolWidget
  # this class is a mess. if you want clean code, write your own damn GUI.

  getFamilies: -> [
    {name: 'Sans-serif', value: '"Helvetica Neue",Helvetica,Arial,sans-serif'},
    {name: 'Serif', value: (
      'Garamond,Baskerville,"Baskerville Old Face",'
      '"Hoefler Text","Times New Roman",serif')}
    {name: 'Typewriter', value: (
      '"Courier New",Courier,"Lucida Sans Typewriter",'
      '"Lucida Typewriter",monospace')},
  ]

  title: "Text"
  cssSuffix: "text"

  constructor: (args...) ->
    super(args...)

  button: -> "<img src='#{@opts.imageURLPrefix}/text.png'>"
  select: (lc) ->
    @updateTool()
    lc.setTool(@tool)
    # not sure why we need to defer this, but I don't get paid enough to work
    # on this to find out why.
    setTimeout((=>
      @$input.focus()
      @$input.select()
    ), 0)
  makeTool: -> 
    new LC.TextTool()

  options: ->
    return @$el if @$el

    familyOptions = []
    i = 0
    for family in @getFamilies()
      familyOptions.push "<option value=#{i}>#{family.name}</option>"
      i += 1

    @$el = $(
      "<div>
       <input type='text' id='text' placeholder='Enter text here'
        value='#{@tool.text}'>
       <input type='text' id='font-size' value='18'>
       <select id='family'>#{familyOptions.join('')}</select>
       <label for='italic'><input type='checkbox' id='italic'>italic</label>
       <label for='bold'><input type='checkbox' id='bold'>bold</label>
       <span class='instructions'>Click and hold to place text.</span>
       </div>")

    @$input = @$el.find('input#text')
    $fontSize = @$el.find('input#font-size')
    updateAndFocus = =>
      @updateTool()
      @$input.focus()

    @$input.keyup => @updateTool()
    $fontSize.keyup => @updateTool()
    @$input.change(updateAndFocus)
    $fontSize.change(updateAndFocus)
    @$el.find('input#italic').change(updateAndFocus)
    @$el.find('input#bold').change(updateAndFocus)
    @$el.find('#family').change(updateAndFocus)

    @$el

  updateTool: ->
    items = []
    if @$el.find('input#italic').is(':checked')
      items.push('italic')
    if @$el.find('input#bold').is(':checked')
      items.push('bold')
    items.push("#{parseInt(@$el.find('input#font-size').val(), 10)}px")

    familyIndex = parseInt(@$el.find('select#family').val(), 10)
    items.push(@getFamilies()[familyIndex].value)

    @tool.font = items.join(' ')
    @tool.text = @$el.find('input#text').val()


class LC.StampWidget extends LC.ToolWidget

  title: "Stamp"
  cssSuffix: "stamp"
  button: -> "<img src='#{@opts.imageURLPrefix}/stamp.png'>"
  options: ->
    @$el = $("<div id='stampset'><div class='button active' data-stamp='checkmark'><img width='18' height='18' src='#{@opts.imageURLPrefix}/stamps/checkmark.png' alt='Checkmark stamp'></div><div class='button' data-stamp='arrowleft'><img width='18' height='18' src='#{@opts.imageURLPrefix}/stamps/arrowleft.png' alt='Left arrow stamp'></div><div class='button' data-stamp='arrowright'><img width='18' height='18' src='#{@opts.imageURLPrefix}/stamps/arrowright.png' alt='Right arrow stamp'></div><div class='button' data-stamp='star'><img width='18' height='18' src='#{@opts.imageURLPrefix}/stamps/star.png' alt='Star stamp'></div></div>")

    arrowLeftButton = @$el.find('[data-stamp=arrowleft]')
    arrowLeftButton.click (e) => @selectButton(arrowLeftButton)

    arrowRightButton = @$el.find('[data-stamp=arrowright]')
    arrowRightButton.click (e) => @selectButton(arrowRightButton)

    checkmarkButton = @$el.find('[data-stamp=checkmark]')
    checkmarkButton.click (e) => @selectButton(checkmarkButton)

    starButton = @$el.find('[data-stamp=star]')
    starButton.click (e) => @selectButton(starButton)

    return @$el

  selectButton: (t) ->
    @$el.find("#stampset .active").removeClass("active")
    t.addClass("active")
    @tool.currentStamp = t.data("stamp")

  makeTool: -> new LC.StampTool()


class LC.PointerWidget extends LC.ToolWidget

  title: "Pointer"
  cssSuffix: "pointer"
  button: -> "<img src='#{@opts.imageURLPrefix}/laserpointer_tiny.png'>"
  options: ->
    # image size selector
    @$el = $("<span class='brush-width-min'>16 px</span><input type='range' min='16' max='128' step='16' value='#{@tool.pointerSize}'><span class='brush-width-max'>128 px</span><span class='brush-width-val'>(64 px)</span>")
    # pointer style
    #@$el = $("<div id='pointerset'><div class='button active' data-stamp='redlaser'><img width='18' height='18' src='#{@opts.imageURLPrefix}/stamps/laserpointer_red.png' alt='Red laser pointer'></div><div class='button' data-stamp='greenlaser'><img width='18' height='18' src='#{@opts.imageURLPrefix}/stamps/laserpointer_green.png' alt='Green laser pointer'></div><div class='button' data-stamp='handright'><img width='18' height='18' src='#{@opts.imageURLPrefix}/stamps/hand_pointer_right_tb.png' alt='Hand pointing right'></div><div class='button' data-stamp='handleft'><img width='18' height='18' src='#{@opts.imageURLPrefix}/stamps/hand_pointer_left_tb.png' alt='Hand pointing left'></div><div class='button' data-stamp='josh'><img width='18' height='18' src='#{@opts.imageURLPrefix}/stamps/josh_pointer_tb.png' alt='Boosh!'></div></div>")
    @$el = @$el.add("<span id='pointerset'><span class='button active' data-stamp='redlaser'><img width='18' height='18' src='#{@opts.imageURLPrefix}/stamps/laserpointer_red.png' alt='Red laser pointer'></span><span class='button' data-stamp='greenlaser'><img width='18' height='18' src='#{@opts.imageURLPrefix}/stamps/laserpointer_green.png' alt='Green laser pointer'></span></span>")

    $input = @$el.filter('input')

    if $input.size() == 0
      $input = @$el.find('input')

    $brushWidthVal = @$el.filter('.brush-width-val')
    if $brushWidthVal.size() == 0
      $brushWidthVal = @$el.find('.brush-width-val')

    $input.change (e) =>
      @tool.pointerSize = parseInt($(e.currentTarget).val(), 10)
      $brushWidthVal.html("(#{@tool.pointerSize} px)")

    redLaserButton = @$el.find('[data-stamp=redlaser]')
    redLaserButton.click (e) => @selectButton(redLaserButton)

    greenLaserButton = @$el.find('[data-stamp=greenlaser]')
    greenLaserButton.click (e) => @selectButton(greenLaserButton)

    # handLeftButton = @$el.find('[data-stamp=handleft]')
    # handLeftButton.click (e) => @selectButton(handLeftButton)

    # handRightButton = @$el.find('[data-stamp=handright]')
    # handRightButton.click (e) => @selectButton(handRightButton)

    # joshButton = @$el.find('[data-stamp=josh]')
    # joshButton.click (e) => @selectButton(joshButton)

    @$el

  selectButton: (t) ->
    @$el.find("#pointerset .active").removeClass("active")
    t.addClass("active")
    @tool.currentStamp = t.data("stamp")

  makeTool: -> new LC.PointerTool()
