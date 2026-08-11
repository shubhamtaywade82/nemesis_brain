# frozen_string_literal: true

require "securerandom"

class TradeJournal
  COLLECTION = "nemesis_trades"
  VECTOR_DIM = 768

  def initialize(ollama: QuantDesk.ollama_client)
    @ollama = ollama
    @trade_log = []
    @qdrant = build_qdrant_client
    ensure_collection_exists if @qdrant
  end

  def record_trade(symbol:, side:, entry_price:, exit_price:, pnl_r:, thesis:, context:)
    outcome = pnl_r >= 0 ? "WIN (#{pnl_r.round(2)}R)" : "LOSS (#{pnl_r.round(2)}R)"
    text = <<~TEXT.strip
      Trade: #{symbol} #{side.upcase} at #{entry_price} -> #{exit_price}
      Thesis: #{thesis}
      Market context: #{context}
      Outcome: #{outcome}
    TEXT

    entry = {
      id: SecureRandom.uuid,
      vector: embed(text),
      payload: {
        text:,
        pnl_r:,
        symbol:,
        side: side.downcase,
        timestamp: Time.now.to_i,
        win: pnl_r >= 0
      }
    }

    if @qdrant
      @qdrant.points.upsert(collection_name: COLLECTION, points: [entry])
    else
      @trade_log << entry
    end
  end

  def similar_trades(market_context, limit: 4, min_score: 0.72)
    if @qdrant
      similar_trades_from_qdrant(market_context, limit:, min_score:)
    else
      similar_trades_from_log(market_context, limit:)
    end
  end

  # All trades (wins and losses) from the last `days`, used for win-rate estimation.
  def recent_trades(days: 7, limit: 200)
    cutoff = trade_cutoff(days)

    entries = if @qdrant
                scroll_qdrant(filter: { must: [{ key: "timestamp", range: { gte: cutoff } }] }, limit:)
              else
                @trade_log.select { |entry| entry[:payload][:timestamp] >= cutoff }
              end

    entries.first(limit)
  end

  def recent_losses(days: 1, limit: 10)
    cutoff = trade_cutoff(days)

    entries = if @qdrant
                scroll_qdrant(
                  filter: {
                    must: [
                      { key: "win", match: { value: false } },
                      { key: "timestamp", range: { gte: cutoff } }
                    ]
                  },
                  limit:
                )
              else
                @trade_log.select do |entry|
                  payload = entry[:payload]
                  !payload[:win] && payload[:timestamp] >= cutoff
                end
              end

    entries.first(limit)
  end

  private

  def trade_cutoff(days)
    (Time.now - (days * 86_400)).to_i
  end

  def build_qdrant_client
    return nil unless QuantDesk::QDRANT_ENABLED

    require "qdrant"
    Qdrant::Client.new(url: ENV["QDRANT_URL"], api_key: ENV["QDRANT_API_KEY"])
  end

  def embed(text)
    return pseudo_vector(text) unless QuantDesk::LLM_ENABLED

    @ollama.embeddings.embed(model: QuantDesk::EMBED_MODEL, input: text)
  rescue Ollama::Error => e
    warn "[TradeJournal] Embedding failed (#{e.message}). Using pseudo-vector."
    pseudo_vector(text)
  end

  def pseudo_vector(text)
    seed = text.bytes.sum
    Array.new(VECTOR_DIM) { |index| Math.sin(seed + index) }
  end

  def similar_trades_from_qdrant(market_context, limit:, min_score:)
    vector = embed(market_context)
    results = @qdrant.points.search(
      collection_name: COLLECTION,
      vector:,
      limit:,
      score_threshold: min_score
    )

    (results.dig("result") || []).map do |hit|
      payload = hit["payload"]
      "[Score:#{hit['score'].round(2)}] #{payload['text'].strip}"
    end
  end

  def similar_trades_from_log(market_context, limit:)
    query_words = market_context.downcase.split
    @trade_log
      .select { |entry| query_words.any? { |word| entry[:payload][:text].downcase.include?(word) } }
      .last(limit)
      .map { |entry| entry[:payload][:text] }
  end

  def scroll_qdrant(filter:, limit:)
    @qdrant.points.scroll(
      collection_name: COLLECTION,
      filter:,
      limit:,
      with_payload: true
    ).dig("result", "points") || []
  end

  def ensure_collection_exists
    existing = @qdrant.collections.list.dig("result", "collections").to_a.map { |collection| collection["name"] }
    return if existing.include?(COLLECTION)

    @qdrant.collections.create(
      collection_name: COLLECTION,
      vectors: { size: VECTOR_DIM, distance: "Cosine" }
    )
  end
end
