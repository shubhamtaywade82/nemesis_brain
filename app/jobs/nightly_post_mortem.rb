# frozen_string_literal: true

class NightlyPostMortem
  def initialize(hippocampus:, config_path:)
    @memory = hippocampus
    @config_path = config_path
  end

  def run
    losses = @memory.recent_losses(days: 1)
    return puts("Post-mortem: No losses today.") if losses.empty?

    journal = losses.map do |point|
      payload = point.is_a?(Hash) && point["payload"] ? point["payload"] : point[:payload]
      payload["text"] || payload[:text]
    end.join("\n\n")

    review = if NemesisBrain::LLM_ENABLED
               run_llm_review(journal)
             else
               paper_review
             end

    File.open(@config_path, "a") do |file|
      review["new_rules"].each { |rule| file.puts("# #{Date.today}: #{rule}") }
    end

    puts "Post-mortem complete: #{review['summary']}"
    puts "New rules: #{review['new_rules'].join(' | ')}"
  end

  private

  def run_llm_review(journal)
    prompt = <<~PROMPT
      Review today's losing trades:
      #{journal}

      Identify cognitive biases and suggest 2 concrete new rules.
      JSON: { "biases": ["string"], "new_rules": ["Rule 1", "Rule 2"], "summary": "string" }
    PROMPT

    chat = RubyLLM.chat(model: NemesisBrain::REASONING_MODEL, provider: :ollama)
    raw = chat.ask(prompt, response_format: { type: "json_object" }).content.to_s
    cleaned = raw.gsub(/^```json\n?/, "").gsub(/\n?```$/, "").strip
    Oj.load(cleaned)
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
