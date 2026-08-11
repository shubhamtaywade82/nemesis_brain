# frozen_string_literal: true

class NightlyPostMortem
  REVIEW_SCHEMA = {
    "type" => "object",
    "required" => %w[biases new_rules summary],
    "properties" => {
      "biases" => { "type" => "array", "items" => { "type" => "string" } },
      "new_rules" => { "type" => "array", "items" => { "type" => "string" } },
      "summary" => { "type" => "string" }
    }
  }.freeze

  def initialize(hippocampus:, config_path:, ollama: NemesisBrain.ollama_client)
    @memory = hippocampus
    @config_path = config_path
    @ollama = ollama
  end

  def run
    losses = @memory.recent_losses(days: 1)
    return puts("Post-mortem: No losses today.") if losses.empty?

    journal = losses.map { |point| payload_of(point)["text"] }.join("\n\n")
    review = NemesisBrain::LLM_ENABLED ? run_llm_review(journal) : paper_review

    File.open(@config_path, "a") do |file|
      review["new_rules"].each { |rule| file.puts("# #{Date.today}: #{rule}") }
    end

    puts "Post-mortem complete: #{review['summary']}"
    puts "New rules: #{review['new_rules'].join(' | ')}"
  end

  private

  def payload_of(point)
    payload = point.is_a?(Hash) && point.key?("payload") ? point["payload"] : point[:payload]
    payload.transform_keys(&:to_s)
  end

  def run_llm_review(journal)
    prompt = <<~PROMPT
      Review today's losing trades:
      #{journal}

      Identify cognitive biases and suggest 2 concrete new rules.

      Respond ONLY as JSON matching this schema:
      #{Oj.dump(REVIEW_SCHEMA)}
    PROMPT

    @ollama.generate(prompt:, schema: REVIEW_SCHEMA, model: NemesisBrain::REASONING_MODEL)
  rescue Ollama::Error => e
    warn "[NightlyPostMortem] LLM review failed (#{e.message}). Falling back to paper review."
    paper_review
  end

  def paper_review
    {
      "biases" => ["revenge_trading"],
      "new_rules" => [
        "Rule 1: Never add to a losing position.",
        "Rule 2: Wait for A-grade setup confluence before re-entry."
      ],
      "summary" => "Paper-mode post-mortem completed."
    }
  end
end
