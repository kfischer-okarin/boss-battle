require 'lib/debug_mode.rb'
require 'lib/extra_keys.rb'
require 'lib/resources.rb'

require 'app/resources.rb'

def tick(args)
  setup(args) if args.tick_count.zero?
  render(args)
  process_input(args)
  update(args)
end

def setup(args)
  frame_w = 200
  frame_h = 400
  args.state.frame = { x: (1280 - frame_w) / 2, y: 50, w: frame_w, h: frame_h }
  args.state.facing = :down
  args.state.key_frames = [
    {
      tick: 0,
      hip: { x: 0.5, y: 0.33 },
      left_foot: { x: 0.09, y: 0.25 },
      right_foot: { x: 0.7, y: 0.00 }
    },
    {
      tick: 8,
      hip: { x: 0.5, y: 0.31 },
      left_foot: { x: 0.2, y: 0.18 },
      right_foot: { x: 0.5, y: 0.00 }
    },
    {
      tick: 16,
      hip: { x: 0.5, y: 0.33 },
      left_foot: { x: 0.73, y: 0.05 },
      right_foot: { x: 0.08, y: 0.05 }
    },
    {
      tick: 24,
      hip: { x: 0.5, y: 0.32 },
      left_foot: { x: 0.75, y: 0.00 },
      right_foot: { x: 0.08, y: 0.2 }
    },
    {
      tick: 32,
      hip: { x: 0.5, y: 0.29 },
      left_foot: { x: 0.2, y: 0.02 },
      right_foot: { x: 0.4, y: 0.1 }
    },
    {
      tick: 35,
      hip: { x: 0.5, y: 0.33 },
      left_foot: { x: 0.09, y: 0.25 },
      right_foot: { x: 0.7, y: 0.00 }
    }
  ]
  args.state.player_skeleton = {
    hip: { x: 0.5, y: 0.3 },
    thigh_length: 0.15,
    shank_length: 0.2,
    left_foot: { x: 0.2, y: 0.25 },
    right_foot: { x: 0.7, y: 0.00 }
  }
  args.state.animation_frame = 0
  args.state.animation_paused = false
  args.state.animation_length = args.state.key_frames.last[:tick]
  apply_key_frame(args.state.player_skeleton, args.state.key_frames, args.state.animation_frame)
end

def apply_key_frame(skeleton, key_frames, animation_frame)
  previous_frame = key_frames.select { |frame| frame[:tick] <= animation_frame }.last
  next_frame = key_frames.find { |frame| frame[:tick] > animation_frame }

  factor = $args.easing.ease previous_frame[:tick],
                             animation_frame,
                             next_frame[:tick] - previous_frame[:tick],
                             :identity

  skeleton[:hip] = {
    x: previous_frame[:hip].x + (factor * (next_frame[:hip].x - previous_frame[:hip].x)),
    y: previous_frame[:hip].y + (factor * (next_frame[:hip].y - previous_frame[:hip].y))
  }
  skeleton[:left_foot] = {
    x: previous_frame[:left_foot].x + (factor * (next_frame[:left_foot].x - previous_frame[:left_foot].x)),
    y: previous_frame[:left_foot].y + (factor * (next_frame[:left_foot].y - previous_frame[:left_foot].y))
  }
  skeleton[:right_foot] = {
    x: previous_frame[:right_foot].x + (factor * (next_frame[:right_foot].x - previous_frame[:right_foot].x)),
    y: previous_frame[:right_foot].y + (factor * (next_frame[:right_foot].y - previous_frame[:right_foot].y))
  }
end

def render(args)
  render_frame(args)
  render_player(args)
end

def render_frame(args)
  rect = Rectangle.new(args.state.frame)
  args.outputs.primitives << {
    x: rect.x, y: rect.y, w: rect.w, h: rect.h,
  }.border!
end

class Rectangle
  attr_reader :x, :y, :w, :h

  def initialize(rect)
    @x = rect.x
    @y = rect.y
    @w = rect.w
    @h = rect.h
  end

  def absolute_position(relative_position)
    { x: absolute_x(relative_position.x), y: absolute_y(relative_position.y) }
  end

  def absolute_x(relative_x)
    @x + (@w * relative_x)
  end

  def absolute_y(relative_y)
    @y + (@h * relative_y)
  end

  def absolute_h(relative_h)
    @h * relative_h
  end

  def absolute_w(relative_w)
    @w * relative_w
  end
end

class Scale
  def initialize(scale:, center:)
    @scale = scale
    @center = center
  end

  def scale_length(length)
    length * @scale
  end

  def scale_position(position)
    {
      x: @center.x + scale_length(position.x - @center.x),
      y: @center.y + scale_length(position.y - @center.y)
    }
  end
end

def render_player(args)
  rect = Rectangle.new(args.state.frame)
  right_leg_scale = Scale.new(scale: 1.05, center: rect.absolute_position([0.5, 0.5]))
  left_leg_scale = Scale.new(scale: 0.95, center: rect.absolute_position([0.5, 0.5]))
  skeleton = args.state.player_skeleton
  render_leg(args,
    left_leg_scale.scale_position(rect.absolute_position(skeleton[:hip])),
    left_leg_scale.scale_position(rect.absolute_position(skeleton[:left_foot])),
    left_leg_scale.scale_length(rect.absolute_h(skeleton[:thigh_length])),
    left_leg_scale.scale_length(rect.absolute_h(skeleton[:shank_length])),
    color: { r: 0, g: 128, b: 0 }
  )
  render_leg(args,
    right_leg_scale.scale_position(rect.absolute_position(skeleton[:hip])),
    right_leg_scale.scale_position(rect.absolute_position(skeleton[:right_foot])),
    right_leg_scale.scale_length(rect.absolute_h(skeleton[:thigh_length])),
    right_leg_scale.scale_length(rect.absolute_h(skeleton[:shank_length])),
    color: { r: 128, g: 0, b: 0 }
  )
end

FACING_ANGLES = {
  up: 0,
  left: 90,
  down: 180,
  right: 270
}.freeze

def render_leg(args, hip_position, foot_position, thigh_length, shank_length, color:)
  angles = calc_leg_angles(hip_position, foot_position, thigh_length, shank_length)
  render_line(args, hip_position, thigh_length, -angles[:thigh_angle], color)
  render_line(args, foot_position, shank_length, -angles[:shank_angle], color)
  # render_point(args, hip_position, r: 0, g: 128, b: 0)
  # render_point(args, foot_position, r: 128, g: 128, b: 0)
end

def render_point(args, point, attributes)
  args.outputs.primitives << {
    x: point.x - 5, y: point.y - 5, w: 10, h: 10,
    path: :pixel
  }.sprite!(attributes)
end

def render_line(args, point, length, angle, color)
  args.outputs.primitives << {
    x: point.x - 2, y: point.y - 2, w: 4, h: length,
    path: :pixel, r: 0, g: 0, b: 0,
    angle: angle, angle_anchor_x: 0.5, angle_anchor_y: 0
  }.sprite!(color)
end

def process_input(args)
  handle_movement(args)
  handle_animation(args)
end

def handle_movement(args)
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
  # args.state.position[0] += dx
  # args.state.position[1] += dy
  args.state.frame.x += dx
  args.state.frame.y += dy
end

def handle_animation(args)
  key_down = args.inputs.keyboard.key_down
  args.state.animation_paused = !args.state.animation_paused if key_down.space

  if key_down.f
    args.state.animation_frame = (args.state.animation_frame + 1) % args.state.animation_length
  elsif key_down.b
    args.state.animation_frame = (args.state.animation_frame - 1) % args.state.animation_length
  end
end

def calc_leg_angles(hip, foot, thigh_length, shank_length)
  # Use minimum distance to avoid breaking on extremely small distances
  d_squared = [((foot.x - hip.x)**2) + ((foot.y - hip.y)**2), 500].max
  d = Math.sqrt(d_squared)

  # atan2 is from x axis counterclockwise
  # subtract from pi/2 to get from y axis clockwise
  alpha = (Math::PI / 2) - Math.atan2(foot.y - hip.y, foot.x - hip.x)
  # $args.outputs.labels << [10, 680, "alpha: #{alpha.to_degrees.round}"]

  if d > thigh_length + shank_length
    return {
      thigh_angle: alpha.to_degrees,
      shank_angle: (Math::PI + alpha).to_degrees
    }
  end

  a = ((thigh_length**2) - (shank_length**2) + d_squared) / (2 * d)
  beta = Math.acos((a / thigh_length).clamp(-1, 1))
  # $args.outputs.labels << [10, 660, "beta: #{beta.to_degrees.round}"]

  thigh_angle = alpha - beta
  # $args.outputs.labels << [10, 640, "thigh_angle: #{thigh_angle.to_degrees.round}"]

  b = d - a
  delta = Math.acos((b / shank_length).clamp(-1, 1))

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

def update(args)
  unless args.state.animation_paused
    args.state.animation_frame = (args.state.animation_frame + 1) % args.state.animation_length
  end
  apply_key_frame(args.state.player_skeleton, args.state.key_frames, args.state.animation_frame)
end

$gtk.reset
