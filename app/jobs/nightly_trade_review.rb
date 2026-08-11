# frozen_string_literal: true

class NightlyTradeReview
  REVIEW_SCHEMA = {
    "type" => "object",
    "required" => %w[biases new_rules summary],
    "properties" => {
      "biases" => { "type" => "array", "items" => { "type" => "string" } },
      "new_rules" => { "type" => "array", "items" => { "type" => "string" } },
      "summary" => { "type" => "string" }
    }
  }.freeze

  def initialize(journal:, config_path:, ollama: QuantDesk.ollama_client)
    @journal = journal
    @config_path = config_path
    @ollama = ollama
  end

  def run
    losses = @journal.recent_losses(days: 1)
    return puts("Trade review: No losses today.") if losses.empty?

    journal_text = losses.map { |entry| payload_of(entry)["text"] }.join("\n\n")
    review = QuantDesk::LLM_ENABLED ? run_llm_review(journal_text) : paper_review

    File.open(@config_path, "a") do |file|
      review["new_rules"].each { |rule| file.puts("# #{Date.today}: #{rule}") }
    end

    puts "Trade review complete: #{review["summary"]}"
    puts "New rules: #{review["new_rules"].join(" | ")}"
  end

  private

  def payload_of(entry)
    payload = entry.is_a?(Hash) && entry.key?("payload") ? entry["payload"] : entry[:payload]
    payload.transform_keys(&:to_s)
  end

  def run_llm_review(journal_text)
    prompt = <<~PROMPT
      Review today's losing trades:
      #{journal_text}

      Identify cognitive biases and suggest 2 concrete new rules.

      Respond ONLY as JSON matching this schema:
      #{Oj.dump(REVIEW_SCHEMA)}
    PROMPT

    @ollama.generate(prompt:, schema: REVIEW_SCHEMA, model: QuantDesk::REASONING_MODEL)
  rescue Ollama::Error => e
    warn "[NightlyTradeReview] LLM review failed (#{e.message}). Falling back to paper review."
    paper_review
  end

  def paper_review
    {
      "biases" => ["revenge_trading"],
      "new_rules" => [
        "Rule 1: Never add to a losing position.",
        "Rule 2: Wait for A-grade setup confluence before re-entry."
      ],
      "summary" => "Paper-mode trade review completed."
    }
  end
end
