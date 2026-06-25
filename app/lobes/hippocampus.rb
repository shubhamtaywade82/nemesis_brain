# frozen_string_literal: true

require "securerandom"

class Hippocampus
  COLLECTION = "nemesis_episodes"
  VECTOR_DIM = 768

  def initialize
    @memory_store = []
    @qdrant = build_qdrant_client
    ensure_collection_exists if @qdrant
  end

  def store_episode(symbol:, side:, entry_price:, exit_price:, pnl_r:, thesis:, context:)
    outcome = pnl_r >= 0 ? "WIN (#{pnl_r.round(2)}R)" : "LOSS (#{pnl_r.round(2)}R)"
    text = <<~TEXT.strip
      Trade: #{symbol} #{side.upcase} at #{entry_price} -> #{exit_price}
      Thesis: #{thesis}
      Market context: #{context}
      Outcome: #{outcome}
    TEXT

    point = {
      id: SecureRandom.uuid,
      vector: embed(text),
      payload: {
        text:,
        pnl_r:,
        symbol:,
        timestamp: Time.now.to_i,
        win: pnl_r >= 0
      }
    }

    if @qdrant
      @qdrant.points.upsert(collection_name: COLLECTION, points: [point])
    else
      @memory_store << point
    end
  end

  def recall(market_context, limit: 4, min_score: 0.72)
    if @qdrant
      recall_from_qdrant(market_context, limit:, min_score:)
    else
      recall_from_memory(market_context, limit:)
    end
  end

  def recent_losses(days: 1, limit: 10)
    cutoff = (Time.now - days * 86_400).to_i
    points = if @qdrant
               scroll_qdrant_losses(cutoff, limit)
             else
               @memory_store.select do |point|
                 payload = point[:payload]
                 !payload[:win] && payload[:timestamp] >= cutoff
               end
             end

    points.first(limit)
  end

  private

  def build_qdrant_client
    return nil unless NemesisBrain::QDRANT_ENABLED

    require "qdrant"
    Qdrant::Client.new(url: ENV["QDRANT_URL"], api_key: ENV["QDRANT_API_KEY"])
  end

  def embed(text)
    return pseudo_vector(text) unless NemesisBrain::LLM_ENABLED

    RubyLLM.embed(text, model: NemesisBrain::EMBED_MODEL, provider: :ollama).vectors.first
  rescue StandardError => e
    warn "[Hippocampus] Embedding failed (#{e.message}). Using pseudo-vector."
    pseudo_vector(text)
  end

  def pseudo_vector(text)
    seed = text.bytes.sum
    Array.new(VECTOR_DIM) { |index| Math.sin(seed + index) }
  end

  def recall_from_qdrant(market_context, limit:, min_score:)
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

  def recall_from_memory(market_context, limit:)
    query = market_context.downcase
    @memory_store
      .select { |point| point[:payload][:text].downcase.include?(query.split.first.to_s) }
      .last(limit)
      .map { |point| point[:payload][:text] }
  end

  def scroll_qdrant_losses(cutoff, limit)
    @qdrant.points.scroll(
      collection_name: COLLECTION,
      filter: {
        must: [
          { key: "win", match: { value: false } },
          { key: "timestamp", range: { gte: cutoff } }
        ]
      },
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
