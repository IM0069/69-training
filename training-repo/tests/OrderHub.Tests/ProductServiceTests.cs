using OrderHub.Core.Domain;
using OrderHub.Core.Services;

namespace OrderHub.Tests;

public class ProductServiceTests
{
    [Fact]
    public async Task GetAll_ReturnsAllProductsIncludingInactive()
    {
        using var db = TestSetup.CreateContext();
        var service = TestSetup.CreateProductService(db);
        TestSetup.AddProduct(db, sku: "SKU-A001");
        TestSetup.AddProduct(db, sku: "SKU-A002", isActive: false);

        var products = await service.GetAllAsync();

        Assert.Equal(2, products.Count);
    }

    [Fact]
    public async Task GetActive_ExcludesInactiveProducts()
    {
        using var db = TestSetup.CreateContext();
        var service = TestSetup.CreateProductService(db);
        TestSetup.AddProduct(db, sku: "SKU-A001");
        TestSetup.AddProduct(db, sku: "SKU-A002", isActive: false);

        var products = await service.GetActiveAsync();

        Assert.All(products, p => Assert.True(p.IsActive));
        Assert.Single(products);
    }

    [Fact]
    public async Task GetLowStock_FiltersByThresholdAndSortsByStockAscending()
    {
        using var db = TestSetup.CreateContext();
        var service = TestSetup.CreateProductService(db);
        TestSetup.AddProduct(db, stock: 9, sku: "SKU-B");
        TestSetup.AddProduct(db, stock: 3, sku: "SKU-A");
        TestSetup.AddProduct(db, stock: 10, sku: "SKU-C");

        var products = await service.GetLowStockAsync(10);

        Assert.Equal(new[] { "SKU-A", "SKU-B" }, products.Select(p => p.Sku));
    }

    [Fact]
    public async Task GetLowStock_ExcludesInactiveProducts()
    {
        using var db = TestSetup.CreateContext();
        var service = TestSetup.CreateProductService(db);
        TestSetup.AddProduct(db, stock: 2, sku: "SKU-A");
        TestSetup.AddProduct(db, stock: 1, isActive: false, sku: "SKU-B");

        var products = await service.GetLowStockAsync(10);

        Assert.Single(products);
        Assert.Equal("SKU-A", products.Single().Sku);
    }

    [Fact]
    public async Task GetLowStock_SoldQuantityLast30Days_ExcludesCancelledOrders()
    {
        using var db = TestSetup.CreateContext();
        var productService = TestSetup.CreateProductService(db);
        var orderService = TestSetup.CreateOrderService(db);
        var customer = TestSetup.AddCustomer(db);
        var product = TestSetup.AddProduct(db, stock: 20, sku: "SKU-A");

        await orderService.CreateOrderAsync(customer.Id, new[] { new NewOrderLine(product.Id, 3) });
        var cancelledOrder = (await orderService.CreateOrderAsync(customer.Id, new[] { new NewOrderLine(product.Id, 4) })).Value!;
        cancelledOrder.Status = OrderStatus.Cancelled;
        await db.SaveChangesAsync();

        var products = await productService.GetLowStockAsync(100);

        Assert.Equal(3, products.Single().SoldQuantityLast30Days);
    }
}
