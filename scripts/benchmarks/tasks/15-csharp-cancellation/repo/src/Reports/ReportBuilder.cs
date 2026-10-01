namespace Reports;

public sealed class ReportBuilder
{
    public async Task<string> BuildAsync(IEnumerable<string> sections, CancellationToken cancellationToken = default)
    {
        var parts = new List<string>();
        foreach (var section in sections)
        {
            await Task.Delay(100);
            parts.Add($"## {section}");
        }
        return string.Join("\n", parts);
    }
}
