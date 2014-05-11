
{last} = require './helpers'
{inspect} = require 'util'

$ = require './symbols'

HTML_ELEMENTS = require('./htmlelements')

stringEscape = require './stringescape'

occurrences = require './occurrences'

module.exports = serialise = (parseTree) ->
  env = {serialiseNode}
  if parseTree.children and
  parseTree.children.length and
  parseTree.children[0].type is $.CJSX_PRAGMA
    env.domObject = parseTree.children[0].value
  else
    env.domObject = 'React.DOM'

  env.serialiseNode(parseTree)

serialiseNode = (node) ->
  unless serialisers[node.type]?
    throw new Error("unknown parseTree node type #{node.type}")

  serialised = serialisers[node.type](node, this)

  unless typeof serialised is 'string' or serialised is null
    throw new Error("serialiser #{node.type} didn\'t return a string for node #{inspect(node)}, instead returned #{serialised}")

  serialised


genericBranchSerialiser = (node, env) ->
  node.children
    .map((child) -> env.serialiseNode child)
    .join('')

genericLeafSerialiser = (node, env) -> node.value

serialise.serialisers = serialisers =
  ROOT: genericBranchSerialiser

  CJSX_PRAGMA: -> null

  CJSX_EL: (node, env) ->
    childrenSerialised = node.children
      .map((child) -> env.serialiseNode child)
      .filter((child) -> child?) # filter empty text nodes
      .join(', ')

    prefix = if HTML_ELEMENTS[node.value]? then env.domObject+'.' else ''
    prefix+node.value+'('+childrenSerialised+')'

  CJSX_ESC: (node, env) ->
    childrenSerialised = node.children
      .map((child) -> env.serialiseNode child)
      .join('')
    '('+childrenSerialised+')'

  CJSX_ATTRIBUTES: (node, env) ->
    # whitespace (particularly newlines) must be maintained for attrs
    # to ensure line number parity
    nonWhitespaceChildren = node.children.filter (child) ->
      child.type isnt $.CJSX_WHITESPACE
    
    lastNonWhitespaceChild = last(nonWhitespaceChildren)

    if nonWhitespaceChildren.length
      childrenSerialised = node.children
        .map (child) ->
          serialised = env.serialiseNode child
          if child.type is $.CJSX_WHITESPACE
            if containsNewlines(serialised)
              serialised.replace('\n',' \\\n')
            else
              null # whitespace without newlines is not significant
          else if child is lastNonWhitespaceChild
            serialised
          else
            serialised+', '
        .join('')
        
      '{'+childrenSerialised+'}'
    else
      'null'

  CJSX_ATTR_PAIR: (node, env) ->
    node.children
      .map((child) -> env.serialiseNode child)
      .join(': ')

  # leaf nodes
  CS: genericLeafSerialiser
  CS_COMMENT: genericLeafSerialiser
  CS_HEREDOC: genericLeafSerialiser
  CS_STRING: genericLeafSerialiser
  JS_ESC: genericLeafSerialiser
  CJSX_WHITESPACE: genericLeafSerialiser

  CJSX_TEXT: (node) ->
    # trim whitespace only if it includes a newline
    text = node.value
    if containsNewlines(text) and WHITESPACE_ONLY.test text
      text.replace('\n','\\\n')
    else
      leftSpace = text.match TEXT_LEADING_WHITESPACE
      rightSpace = text.match TEXT_TRAILING_WHITESPACE

      leftTrim = leftSpace and leftSpace[0].length or 0
      rightTrim = rightSpace and rightSpace.index or text.length

      trimmedText = text.substring(leftTrim, rightTrim)

      if trimmedText == ''
        null # this text node will be omitted
      else
        '"""'+trimmedText+'"""'

  CJSX_ATTR_KEY: genericLeafSerialiser
  CJSX_ATTR_VAL: genericLeafSerialiser



containsNewlines = (text) -> text.indexOf('\n') > -1

SPACES_ONLY = /^\s+$/

WHITESPACE_ONLY = /^[^\n\S]+$/

# leading and trailing whitespace which contains a newline
TEXT_LEADING_WHITESPACE = /^\s*?\n\s*/
TEXT_TRAILING_WHITESPACE = /\s*?\n\s*?$/
