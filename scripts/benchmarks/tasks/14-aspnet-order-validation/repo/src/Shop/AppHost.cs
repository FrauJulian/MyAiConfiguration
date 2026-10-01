namespace Shop;

public static class AppHost
{
    // Integration tests start the application through Build.
    public static WebApplication Build(string[] args)
    {
        var builder = WebApplication.CreateBuilder(args);
        var app = builder.Build();
        var orders = new List<Order>();
        app.MapPost("/orders", (Order order) =>
        {
            orders.Add(order);
            return Results.Created($"/orders/{orders.Count}", order);
        });
        return app;
    }
}

public record Order(string Sku, int Quantity);
