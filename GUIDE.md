## Using Axelar GMP for Cross-Chain Gas Payments

### Why Is Gas Abstraction Important?

Typically, users must hold native gas tokens on every chain they interact with. This requirement is cumbersome for mainstream adoption and can deter users from exploring new chains. Allowing users to pay gas with a stablecoin—rather than forcing them to acquire the native chain token—simplifies the on-chain experience and makes dApps more accessible. While current solutions exist, they are limited. 

| **Limitation**                                         | **Manual Bridging** | **Meta-Transactions** | **Account Abstraction** | **Axelar GMP** |
|--------------------------------------------------------|:-------------------:|:---------------------:|:-----------------------:|:--------------:|
| **User must hold multiple chain tokens for gas**       |         X           |          X            |           X             |       ✓        |
| **Relies on external relayer or centralized service**  |         –           |          X            |           –             |       ✓        |
| **Complex bridging overhead / user friction**          |         X           |          –            |           –             |       ✓        |
| **Cannot easily pay gas with stablecoins**             |         X           |          X<sup>1</sup>|           X<sup>2</sup> |       ✓        |
| **Limited or partial network support**                 |         X           |          X            |           X             |       ✓        |

<sup>1</sup> Some meta‐transaction solutions allow ERC20 gas payments but depend on specialized relayers and are not widely standardized.  
<sup>2</sup> While ERC‐4337 + Paymasters can enable ERC20 gas, it remains complex and is not broadly supported across all chains.


