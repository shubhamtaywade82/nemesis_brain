# frozen_string_literal: true

require "descriptive_statistics/safe"

class Amygdala
  MAX_RISK_PER_TRADE = 0.01
  MAX_DAILY_DRAWDOWN = 0.03
  MAX_LEVERAGE = 20
  MIN_RR_RATIO = 2.0

  attr_reader :desk_open, :session_pnl

  def initialize(nervous_system:, equity:)
    @ns = nervous_system
    @equity = equity
    @session_pnl = 0.0
    @desk_open = true
    @ns.subscribe(self)
  end

  def trade_plan_generated(plan)
    unless @desk_open
      log("AMYGDALA: Desk closed. Rejecting trade plan.")
      return
    end

    entry = plan["entry_zone"]["high"].to_f
    stop = plan["invalidation_price"].to_f
    target1 = plan["targets"][0].to_f

    stop_distance = (entry - stop).abs / entry
    reward_distance = (target1 - entry).abs / entry
    rr_ratio = reward_distance / stop_distance

    if rr_ratio < MIN_RR_RATIO
      log("AMYGDALA: R:R #{rr_ratio.round(2)} below #{MIN_RR_RATIO}. Rejected.")
      return
    end

    win_rate = 0.45
    kelly_fraction = (win_rate - ((1 - win_rate) / rr_ratio)) * 0.25
    kelly_fraction = kelly_fraction.clamp(0.0, MAX_RISK_PER_TRADE)

    risk_amount = @equity * kelly_fraction
    position_size = risk_amount / stop_distance
    leverage = (position_size / @equity).ceil.clamp(1, MAX_LEVERAGE)
    adjusted_size = position_size * (1.0 - correlation_penalty(plan["side"]))

    log("AMYGDALA: APPROVED size=$#{adjusted_size.round(2)} leverage=#{leverage}x R:R=#{rr_ratio.round(2)}")

    @ns.broadcast(
      :approved_order,
      {
        plan:,
        size_usd: adjusted_size,
        leverage:,
        risk_pct: kelly_fraction * 100,
        rr_ratio:
      }
    )
  end

  def trade_closed(event)
    pnl_usd = event[:pnl_usd]
    @session_pnl += pnl_usd
    drawdown_pct = -@session_pnl / @equity

    return unless drawdown_pct >= MAX_DAILY_DRAWDOWN

    @desk_open = false
    log("AMYGDALA: Daily drawdown #{(drawdown_pct * 100).round(2)}% breached. Desk closed.")
    @ns.broadcast(:desk_closed, { reason: "daily_drawdown_limit" })
  end

  private

  def correlation_penalty(_side)
    0.0
  end

  def log(message)
    puts(NemesisBrain::Log.colorize("[#{Time.now.strftime('%H:%M:%S')}] #{message}", :red))
  end
end
