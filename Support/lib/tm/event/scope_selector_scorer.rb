# Taken from http://textpow.rubyforge.org/svn/lib/textpow/score_manager.rb

module TextMate
  module Event
    class ScopeSelectorScorer

      class ParsingError < Exception; end

      POINT_DEPTH    = 4
      NESTING_DEPTH  = 40
      START_VALUE    = 2 ** ( POINT_DEPTH * NESTING_DEPTH )
      BASE           = 2 ** POINT_DEPTH

      def initialize
         @scores = {}
      end

      def score scope_selector, reference_scope
         max = 0
         scope_selector.split( ',' ).each do |scope|
            arrays = scope.split(/\B-/)
            if arrays.size == 1
               max = [max, score_term( arrays[0], reference_scope )].max
            elsif arrays.size > 1
               excluded = false
               arrays[1..-1].each do |a| 
                  if score_term( arrays[1], reference_scope ) > 0
                     excluded = true
                     break
                  end
               end
               max = [max, score_term( arrays[0], reference_scope )].max unless excluded
            else
               raise ParsingError, "Error in scope string: '#{scope_selector}' #{arrays.size} is not a valid number of operands" if arrays.size < 1
            end
         end
         max
      end   

      private

      def score_term scope_selector, reference_scope
         unless @scores[reference_scope] && @scores[reference_scope][scope_selector]
            @scores[reference_scope] ||= {}
            @scores[reference_scope][scope_selector] = score_array( scope_selector.split(' '), reference_scope.split( ' ' ) )
         end
         @scores[reference_scope][scope_selector]
      end

      def score_array scope_selector_array, reference_array
         pending = scope_selector_array
         current = reference_array.last
         reg = Regexp.new( "^#{Regexp.escape( pending.last )}" )
         multiplier = START_VALUE
         result = 0
         while pending.size > 0 && current
            if reg =~ current
               point_score = (2**POINT_DEPTH) - current.count( '.' ) + Regexp.last_match[0].count( '.' )
               result += point_score * multiplier
               pending.pop
               reg = Regexp.new( "^#{Regexp.escape( pending.last )}" ) if pending.size > 0
            end
            multiplier = multiplier / BASE
            reference_array.pop
            current = reference_array.last
         end
         result = 0 if pending.size > 0
         result
      end
    end
    
  end
end