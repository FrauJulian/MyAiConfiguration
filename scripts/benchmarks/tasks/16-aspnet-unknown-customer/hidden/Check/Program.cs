using System.Net;
using System.Text;
using Microsoft.AspNetCore.Hosting.Server;
using Microsoft.AspNetCore.Hosting.Server.Features;
using Microsoft.Extensions.DependencyInjection;

var app = Crm.AppHost.Build(new[] { "--urls", "http://127.0.0.1:0" });
await app.StartAsync();
var address = app.Services.GetRequiredService<IServer>().Features.Get<IServerAddressesFeature>()!.Addresses.First();
using var client = new HttpClient { BaseAddress = new Uri(address) };
var failures = new List<string>();
var known = await client.GetAsync("/customers/1");
if (known.StatusCode != HttpStatusCode.OK || !(await known.Content.ReadAsStringAsync()).Contains("Ada")) failures.Add($"known customer -> {(int)known.StatusCode}");
var unknown = await client.GetAsync("/customers/42");
if (unknown.StatusCode != HttpStatusCode.NotFound) failures.Add($"unknown customer -> {(int)unknown.StatusCode}");
await app.StopAsync();
foreach (var failure in failures) Console.Error.WriteLine("FAIL " + failure);
return failures.Count == 0 ? 0 : 1;
