using System.Net;
using System.Text;
using Microsoft.AspNetCore.Hosting.Server;
using Microsoft.AspNetCore.Hosting.Server.Features;
using Microsoft.Extensions.DependencyInjection;

var app = Shop.AppHost.Build(new[] { "--urls", "http://127.0.0.1:0" });
await app.StartAsync();
var address = app.Services.GetRequiredService<IServer>().Features.Get<IServerAddressesFeature>()!.Addresses.First();
using var client = new HttpClient { BaseAddress = new Uri(address) };
var failures = new List<string>();
async Task Expect(string json, int status)
{
    var response = await client.PostAsync("/orders", new StringContent(json, Encoding.UTF8, "application/json"));
    if ((int)response.StatusCode != status) failures.Add($"{json} -> {(int)response.StatusCode}, expected {status}");
    else if (status == 400 && response.Content.Headers.ContentType?.MediaType != "application/problem+json") failures.Add($"{json} -> 400 without problem details");
}
await Expect("{\"sku\":\"A1\",\"quantity\":2}", 201);
await Expect("{\"sku\":\"A1\",\"quantity\":0}", 400);
await Expect("{\"sku\":\"A1\",\"quantity\":-3}", 400);
await Expect("{\"sku\":\"\",\"quantity\":1}", 400);
await app.StopAsync();
foreach (var failure in failures) Console.Error.WriteLine("FAIL " + failure);
return failures.Count == 0 ? 0 : 1;
