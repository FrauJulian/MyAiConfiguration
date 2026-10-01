using System.Diagnostics;
using Reports;

var failures = new List<string>();
var builder = new ReportBuilder();
var complete = await builder.BuildAsync(new[] { "a", "b" });
if (complete != "## a\n## b") failures.Add($"unexpected output {complete}");
using var source = new CancellationTokenSource(TimeSpan.FromMilliseconds(150));
var watch = Stopwatch.StartNew();
try
{
    await builder.BuildAsync(Enumerable.Range(0, 50).Select(number => number.ToString()), source.Token);
    failures.Add("no cancellation");
}
catch (OperationCanceledException)
{
    if (watch.ElapsedMilliseconds > 1000) failures.Add($"cancelled only after {watch.ElapsedMilliseconds} ms");
}
foreach (var failure in failures) Console.Error.WriteLine("FAIL " + failure);
return failures.Count == 0 ? 0 : 1;
