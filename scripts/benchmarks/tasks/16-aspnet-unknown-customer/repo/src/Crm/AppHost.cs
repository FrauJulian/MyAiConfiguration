namespace Crm;

public static class AppHost
{
    // Integration tests start the application through Build.
    public static WebApplication Build(string[] args)
    {
        var builder = WebApplication.CreateBuilder(args);
        var app = builder.Build();
        var customers = new Dictionary<int, Customer> { [1] = new(1, "Ada") };
        app.MapGet("/customers/{id:int}", (int id) => customers[id]);
        return app;
    }
}

public record Customer(int Id, string Name);
