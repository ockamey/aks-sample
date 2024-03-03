using Microsoft.AspNetCore.Mvc;
using Azure.Identity;
using Azure.Security.KeyVault.Secrets;

namespace api.Controllers;

[ApiController]
[Route("[controller]")]
public class EnvironmentController : ControllerBase
{
    private readonly ILogger<EnvironmentController> _logger;

    public EnvironmentController(ILogger<EnvironmentController> logger)
    {
        _logger = logger;
    }

    [HttpGet(Name = "GetEnv2")]
    public async Task<string> Get()
    {
        string envString = Environment.GetEnvironmentVariable("ENV_VAR");

        string keyVaultName = Environment.GetEnvironmentVariable("KEY_VAULT_NAME");
        var kvUri = "https://" + keyVaultName + ".vault.azure.net";

        var client = new SecretClient(new Uri(kvUri), new WorkloadIdentityCredential());

        var secret = await client.GetSecretAsync("secretName");

        return envString + "; Secret: " + secret.Value.Value;
    }
}
