require 'lib/debug_mode.rb'
require 'lib/extra_keys.rb'
require 'lib/resources.rb'

require 'app/resources.rb'

def tick(args)
  setup(args) if args.tick_count.zero?
  render(args)
  process_input(args)
end

def setup(args)
  args.state.position = [640, 360]
  args.state.facing = :down
end

def render(args)
  render_player(args)
end

def render_player(args)
  height = 40
  size = 40
  args.outputs.primitives << height.times.map { |y|
    {
      x: args.state.position[0] - size.idiv(2),
      y: args.state.position[1] - size.idiv(2) + y,
      w: size,
      h: size,
      path: 'resources/player.png',
      angle_anchor_x: 0.5,
      angle_anchor_y: 0.4
    }.sprite!(angle: FACING_ANGLES[args.state.facing])
  }

  args.outputs.primitives << {
    x: args.state.position[0] - 5,
    y: args.state.position[1] - 5,
    w: 10,
    h: 10,
    r: 255,
    g: 0,
    b: 0
  }.solid!
end

FACING_ANGLES = {
  up: 0,
  left: 90,
  down: 180,
  right: 270
}.freeze

def process_input(args)
  key_held = args.inputs.keyboard.key_held
  if key_held.up
    args.state.position[1] += 5
    args.state.facing = :up
  elsif key_held.down
    args.state.position[1] -= 5
    args.state.facing = :down
  end

  if key_held.left
    args.state.position[0] -= 5
    args.state.facing = :left
  elsif key_held.right
    args.state.position[0] += 5
    args.state.facing = :right
  end
end

$gtk.reset
