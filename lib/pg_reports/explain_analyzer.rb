# frozen_string_literal: true

module PgReports
  # Analyzes EXPLAIN ANALYZE output and extracts insights
  class ExplainAnalyzer
    # Node types and their characteristics
    NODE_TYPES = {
      "Seq Scan" => {color: "warning", description: "Full table scan - potentially slow for large tables"},
      "Index Scan" => {color: "good", description: "Using an index efficiently"},
      "Index Only Scan" => {color: "good", description: "Most efficient - reading only from index"},
      "Bitmap Index Scan" => {color: "ok", description: "First step of bitmap scan"},
      "Bitmap Heap Scan" => {color: "ok", description: "Using multiple indexes combined"},
      "Nested Loop" => {color: "neutral", description: "Joining tables in a loop"},
      "Hash Join" => {color: "good", description: "Efficient join using hash table"},
      "Merge Join" => {color: "good", description: "Efficient join on sorted data"},
      "Sort" => {color: "warning", description: "Sorting data in memory or disk"},
      "HashAggregate" => {color: "ok", description: "Grouping using hash table"},
      "GroupAggregate" => {color: "ok", description: "Grouping on sorted data"},
      "Aggregate" => {color: "ok", description: "Computing aggregate functions"},
      "Limit" => {color: "good", description: "Limiting result set"},
      "Subquery Scan" => {color: "neutral", description: "Scanning a subquery result"},
      "CTE Scan" => {color: "neutral", description: "Scanning a Common Table Expression"},
      "Materialize" => {color: "warning", description: "Caching intermediate results"},
      "Gather" => {color: "ok", description: "Parallel query coordination"},
      "Gather Merge" => {color: "ok", description: "Parallel query with merge"}
    }.freeze

    attr_reader :raw_output, :lines, :problems, :summary

    def initialize(explain_output)
      @raw_output = explain_output
      @lines = explain_output.split("\n")
      @problems = []
      @summary = {}
      analyze
    end

    def to_h
      {
        raw_output: @raw_output,
        annotated_lines: annotate_lines,
        problems: @problems,
        summary: @summary,
        stats: extract_stats
      }
    end

    private

    def analyze
      detect_sequential_scans
      detect_high_cost_operations
      detect_sort_operations
      detect_low_row_accuracy
      detect_timing_issues
      build_summary
    end

    # Annotate each line with metadata for rendering
    def annotate_lines
      @lines.map.with_index do |line, idx|
        node_type = extract_node_type(line)
        metrics = extract_metrics(line)

        {
          line_number: idx + 1,
          text: line,
          node_type: node_type,
          node_info: NODE_TYPES[node_type],
          metrics: metrics,
          indent_level: line[/^ */].length / 2,
          is_planning: line.include?("Planning"),
          is_execution: line.include?("Execution"),
          is_timing: line.match?(/Planning Time|Execution Time/)
        }
      end
    end

    def extract_node_type(line)
      NODE_TYPES.keys.find { |type| line.include?(type) }
    end

    def extract_metrics(line)
      metrics = {}

      # Extract cost
      if (match = line.match(/cost=([\d.]+)\.\.([\d.]+)/))
        metrics[:startup_cost] = match[1].to_f
        metrics[:total_cost] = match[2].to_f
      end

      # Extract rows
      if (match = line.match(/rows=(\d+)/))
        metrics[:rows_estimated] = match[1].to_i
      end

      # Extract actual rows
      if (match = line.match(/rows=(\d+).*actual.*rows=(\d+)/))
        metrics[:rows_estimated] = match[1].to_i
        metrics[:rows_actual] = match[2].to_i
      elsif (match = line.match(/actual.*rows=(\d+)/))
        metrics[:rows_actual] = match[1].to_i
      end

      # Extract actual time
      if (match = line.match(/actual time=([\d.]+)\.\.([\d.]+)/))
        metrics[:actual_time_start] = match[1].to_f
        metrics[:actual_time_end] = match[2].to_f
      end

      # Extract loops
      if (match = line.match(/loops=(\d+)/))
        metrics[:loops] = match[1].to_i
      end

      # Extract buffers
      if (match = line.match(/Buffers: shared hit=(\d+)/))
        metrics[:buffers_hit] = match[1].to_i
      end
      if (match = line.match(/read=(\d+)/))
        metrics[:buffers_read] = match[1].to_i
      end

      metrics
    end

    def extract_stats
      stats = {}

      @lines.each do |line|
        if (match = line.match(/Planning Time: ([\d.]+) ms/))
          stats[:planning_time] = match[1].to_f
        elsif (match = line.match(/Execution Time: ([\d.]+) ms/))
          stats[:execution_time] = match[1].to_f
        end
      end

      # Extract top-level cost and rows from first line with cost
      first_cost_line = @lines.find { |l| l.include?("cost=") }
      if first_cost_line
        if (match = first_cost_line.match(/cost=[\d.]+\.\.([\d.]+)/))
          stats[:total_cost] = match[1].to_f
        end
        if (match = first_cost_line.match(/rows=(\d+)/))
          stats[:rows_estimated] = match[1].to_i
        end
      end

      stats
    end

    def detect_sequential_scans
      seq_scans = []

      @lines.each_with_index do |line, idx|
        next unless line.include?("Seq Scan")

        table_name = extract_table_name(line)
        metrics = extract_metrics(line)

        # Consider it a problem if:
        # 1. High cost (> 1000)
        # 2. Many rows (> 1000)
        # 3. Significant actual time (> 100ms per loop)
        is_problem = false
        reasons = []

        if metrics[:total_cost] && metrics[:total_cost] > 1000
          is_problem = true
          reasons << "high cost (#{metrics[:total_cost].round(2)})"
        end

        if metrics[:rows_estimated] && metrics[:rows_estimated] > 1000
          is_problem = true
          reasons << "many rows (#{metrics[:rows_estimated]})"
        end

        if metrics[:actual_time_end] && metrics[:actual_time_end] > 100
          is_problem = true
          reasons << "slow execution (#{metrics[:actual_time_end].round(2)}ms)"
        end

        if is_problem
          @problems << {
            type: :sequential_scan,
            severity: :warning,
            line_number: idx + 1,
            table: table_name,
            message: "Sequential scan on #{table_name || "table"}",
            details: reasons.join(", "),
            recommendation: "Consider adding an index on frequently filtered columns"
          }
        end

        seq_scans << {table: table_name, line: idx + 1, is_problem: is_problem}
      end

      seq_scans
    end

    def detect_high_cost_operations
      @lines.each_with_index do |line, idx|
        metrics = extract_metrics(line)
        next unless metrics[:total_cost]

        # Flag operations with very high cost (> 10000)
        if metrics[:total_cost] > 10000
          node_type = extract_node_type(line)
          @problems << {
            type: :high_cost,
            severity: :warning,
            line_number: idx + 1,
            node_type: node_type,
            cost: metrics[:total_cost],
            message: "Very high cost operation (#{metrics[:total_cost].round(2)})",
            recommendation: "This operation is expensive - review if it can be optimized"
          }
        end
      end
    end

    def detect_sort_operations
      @lines.each_with_index do |line, idx|
        next unless line.include?("Sort")

        # Check if sort spilled to disk
        if line.match?(/external.*sort/i) || line.include?("Disk:")
          @problems << {
            type: :sort_spill,
            severity: :critical,
            line_number: idx + 1,
            message: "Sort operation spilled to disk",
            recommendation: "Increase work_mem or optimize query to reduce sort size"
          }
        elsif line.include?("Sort")
          # Just a regular sort, note it but not necessarily a problem
          metrics = extract_metrics(line)
          if metrics[:actual_time_end] && metrics[:actual_time_end] > 1000
            @problems << {
              type: :slow_sort,
              severity: :warning,
              line_number: idx + 1,
              message: "Slow sort operation (#{metrics[:actual_time_end].round(2)}ms)",
              recommendation: "Consider reducing the dataset before sorting or using an index"
            }
          end
        end
      end
    end

    def detect_low_row_accuracy
      @lines.each_with_index do |line, idx|
        metrics = extract_metrics(line)
        next unless metrics[:rows_estimated] && metrics[:rows_actual]

        estimated = metrics[:rows_estimated].to_f
        actual = metrics[:rows_actual].to_f

        # Skip if very small numbers
        next if estimated < 10 && actual < 10

        # Calculate ratio (avoid division by zero)
        max_val = [estimated, actual].max
        min_val = [estimated, actual].min
        next if max_val == 0

        ratio = max_val / min_val

        # If estimation is off by more than 10x, it's a problem
        if ratio > 10
          @problems << {
            type: :estimation_error,
            severity: :warning,
            line_number: idx + 1,
            message: "Row estimation is significantly off (estimated: #{estimated.to_i}, actual: #{actual.to_i})",
            recommendation: "Run ANALYZE on the involved tables to update statistics"
          }
        end
      end
    end

    def detect_timing_issues
      stats = extract_stats

      if stats[:execution_time] && stats[:execution_time] > 1000
        @problems << {
          type: :slow_query,
          severity: :critical,
          message: "Query execution is very slow (#{stats[:execution_time].round(2)}ms)",
          recommendation: "Review the execution plan for optimization opportunities"
        }
      end

      if stats[:planning_time] && stats[:planning_time] > 100
        @problems << {
          type: :slow_planning,
          severity: :info,
          message: "Query planning is slow (#{stats[:planning_time].round(2)}ms)",
          recommendation: "Consider simplifying the query or using prepared statements"
        }
      end
    end

    def build_summary
      @summary = {
        total_problems: @problems.length,
        critical_problems: @problems.count { |p| p[:severity] == :critical },
        warnings: @problems.count { |p| p[:severity] == :warning },
        info: @problems.count { |p| p[:severity] == :info }
      }

      # Add overall assessment
      if @summary[:critical_problems] > 0
        @summary[:status] = "critical"
        @summary[:status_text] = "Critical issues detected"
        @summary[:status_icon] = "🔴"
      elsif @summary[:warnings] > 0
        @summary[:status] = "warning"
        @summary[:status_text] = "Potential issues detected"
        @summary[:status_icon] = "🟡"
      else
        @summary[:status] = "good"
        @summary[:status_text] = "No issues detected"
        @summary[:status_icon] = "🟢"
      end

      # Group problems by type for summary
      problem_types = @problems.group_by { |p| p[:type] }
      @summary[:problem_breakdown] = problem_types.transform_values(&:count)
    end

    def extract_table_name(line)
      if (match = line.match(/on (\w+)/))
        match[1]
      end
    end
  end
end
