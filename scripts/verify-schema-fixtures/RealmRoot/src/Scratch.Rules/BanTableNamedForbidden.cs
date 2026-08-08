using Microsoft.SqlServer.Dac.CodeAnalysis;
using Microsoft.SqlServer.Dac.Model;

namespace Norse.Scratch.Rules
{
    /// <summary>Fixture rule NR0001: convicts any table literally named <c>forbidden</c>.</summary>
    [ExportCodeAnalysisRule(RuleId, "Fixture rule", Description = "Table name 'forbidden' is banned.", Category = "Fixture", RuleScope = SqlRuleScope.Element)]
    public sealed class BanTableNamedForbidden : SqlCodeAnalysisRule
    {
        /// <summary>The rule's identifier, as registered with DacFx and referenced by <c>SqlCodeAnalysisRules</c> promotion tokens.</summary>
        public const string RuleId = "Scratch.Rules.NR0001";

        /// <summary>Initializes a new instance of the <see cref="BanTableNamedForbidden"/> class.</summary>
        public BanTableNamedForbidden()
        {
            SupportedElementTypes = [ModelSchema.Table];
        }

        /// <inheritdoc />
        public override IList<SqlRuleProblem> Analyze(SqlRuleExecutionContext ruleExecutionContext)
        {
            return ruleExecutionContext.ModelElement?.Name?.Parts?.LastOrDefault() == "forbidden"
                ? [new SqlRuleProblem("Table name 'forbidden' is banned.", ruleExecutionContext.ModelElement)]
                : [];
        }
    }
}
