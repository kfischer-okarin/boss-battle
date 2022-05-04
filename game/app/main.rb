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
  args.state.hip_position = [640, 360]
  args.state.thigh_length = 100
  args.state.shank_length = 120
  args.state.foot_position = [600, 200]
end

def render(args)
  # render_player(args)
  render_leg(args)
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

def render_leg(args)
  angles = calc_leg_angles(
    args.state.hip_position,
    args.state.foot_position,
    args.state.thigh_length,
    args.state.shank_length
  )
  render_line(args, args.state.hip_position, args.state.thigh_length, -angles[:thigh_angle])
  render_line(args, args.state.foot_position, args.state.shank_length, -angles[:shank_angle])
  render_point(args, args.state.hip_position, r: 0, g: 128, b: 0)
  render_point(args, args.state.foot_position, r: 128, g: 128, b: 0)
end

def render_point(args, point, attributes)
  args.outputs.primitives << {
    x: point.x - 5, y: point.y - 5, w: 10, h: 10,
    path: :pixel
  }.sprite!(attributes)
end

def render_line(args, point, length, angle)
  args.outputs.primitives << {
    x: point.x - 2, y: point.y - 2, w: 4, h: length,
    path: :pixel, r: 0, g: 0, b: 0,
    angle: angle, angle_anchor_x: 0.5, angle_anchor_y: 0
  }.sprite!
end

def process_input(args)
  key_held = args.inputs.keyboard.key_held

  held_directions = %i[up down left right].select { |direction|
    key_held.send(direction)
  }
  args.state.facing = held_directions.first if held_directions.size == 1

  speed = 5
  dx = 0
  dx += speed if key_held.right
  dx -= speed if key_held.left
  dy = 0
  dy += speed if key_held.up
  dy -= speed if key_held.down
  if !dx.zero? && !dy.zero?
    dx *= 0.8
    dy *= 0.8
  end
  args.state.position[0] += dx
  args.state.position[1] += dy
end

def calc_leg_angles(hip, foot, thigh_length, shank_length)
  # Use minimum distance to avoid breaking on extremely small distances
  d_squared = [((foot[0] - hip[0])**2) + ((foot[1] - hip[1])**2), 500].max
  d = Math.sqrt(d_squared)

  # atan2 is from x axis counterclockwise
  # subtract from pi/2 to get from y axis clockwise
  alpha = (Math::PI / 2) - Math.atan2(foot[1] - hip[1], foot[0] - hip[0])
  # $args.outputs.labels << [10, 680, "alpha: #{alpha.to_degrees.round}"]

  if d > thigh_length + shank_length
    return {
      thigh_angle: alpha.to_degrees,
      shank_angle: (Math::PI + alpha).to_degrees
    }
  end

  a = ((thigh_length**2) - (shank_length**2) + d_squared) / (2 * d)
  beta = Math.acos(a / thigh_length)
  # $args.outputs.labels << [10, 660, "beta: #{beta.to_degrees.round}"]

  thigh_angle = alpha - beta
  # $args.outputs.labels << [10, 640, "thigh_angle: #{thigh_angle.to_degrees.round}"]

  b = d - a
  delta = Math.acos(b / shank_length)
  # $args.outputs.labels << [10, 620, "delta: #{delta.to_degrees.round}"]
  gamma = alpha + Math::PI
  # $args.outputs.labels << [10, 600, "gamma: #{gamma.to_degrees.round}"]
  shank_angle = gamma + delta
  # $args.outputs.labels << [10, 580, "shank_angle: #{shank_angle.to_degrees.round}"]

  {
    thigh_angle: thigh_angle.to_degrees,
    shank_angle: shank_angle.to_degrees
  }
end

$gtk.reset
