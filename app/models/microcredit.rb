class Microcredit < ActiveRecord::Base
  acts_as_paranoid
  has_many :loans, class_name: "MicrocreditLoan"

  # example: "100€: 100\r500€: 22\r1000€: 10"
  validates :limits, format: { with: /\A(\D*\d+\D*\d+\D*)+\z/, message: "Introduce pares (monto, cantidad)"}

  scope :active, -> {where("? between starts_at and ends_at", DateTime.now)}

  def limits
    @limits ||= parse_limits self[:limits]
  end

  def limits=(l)
    self[:limits] = l
    @limits = parse_limits self[:limits]
  end

  def parse_limits limits_string
    Hash[* limits_string.scan(/\d+/).map {|x| x.to_i} ] if limits_string
  end

  def campaign_status
    # field IS NOT NULL returns integer on SQLite and boolean in postgres, so both values are checked and converted to boolean
    @campaign_status ||= loans.group(:amount, "confirmed_at IS NOT NULL", "counted_at IS NOT NULL").pluck(:amount, "confirmed_at IS NOT NULL", "counted_at IS NOT NULL", "COUNT(*)").sort.map {|x| [x[0], (x[1]||x[1]==1), (x[2]||x[2]==1), x[3]] }
  end

  def phase_status
    # field IS NOT NULL returns integer on SQLite and boolean in postgres, so both values are checked and converted to boolean
    @phase_status ||= loans.phase.group(:amount, "confirmed_at IS NOT NULL", "counted_at IS NOT NULL").pluck(:amount, "confirmed_at IS NOT NULL", "counted_at IS NOT NULL", "COUNT(*)").sort.map {|x| [x[0], (x[1]||x[1]==1), (x[2]||x[2]==1), x[3]] }
  end

  def ellapsed_time_percent
    [ [(DateTime.now.to_f-starts_at.to_f) / (ends_at.to_f-starts_at.to_f), 0.0].max, 100.0].min
  end

  def has_amount_available? amount
    current = phase_status.collect {|x| x[3] if x[0]==amount and x[2] } .compact.sum
    limits[amount] and limits[amount] > current
  end

  def should_count? amount, confirmed
    percent = confirmed ? ellapsed_time_percent : 1-ellapsed_time_percent
    current = campaign_status.collect {|x| x[3] if x[0]==amount and x[1] == confirmed} .compact.sum
    current_counted = campaign_status.collect {|x| x[3] if x[0]==amount and x[1] == confirmed and x[2]} .compact.sum

    current == 0 or (1.0*current_counted/current-percent).abs>((current_counted+1.0)/current-percent).abs
  end

  def phase_remaining
    p phase_status
    limits.map do |amount, limit|
      [amount, [0, limit-phase_status.collect {|x| x[3] if x[0]==amount and x[2]} .compact.sum].max ]
    end
  end

  def phase_limit_amount
    limits.map do |k,v| k*v end .sum
  end

  def phase_counted_amount
    phase_status.collect {|x| x[0]*x[3] if x[2] } .compact.sum
  end

  def campaign_confirmed_amount
    campaign_status.collect {|x| x[0]*x[3] if x[1] } .compact.sum
  end

  def campaign_counted_amount
    campaign_status.collect {|x| x[0]*x[3] if x[2] } .compact.sum
  end

  def change_phase
    self.reset_at = DateTime.now
    save
  end
end
