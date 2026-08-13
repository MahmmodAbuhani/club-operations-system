# Query Outputs

These are the expected outputs from the seed data in `sql/02_seed.sql`, using the same five analytics queries exposed in the Admin reports page.

## Most Popular Sports

```sql
SELECT s.SportName, COUNT(r.PersonID) AS RegisteredPlayers
FROM Sport s
LEFT JOIN Registers r ON r.SportID = s.SportID
GROUP BY s.SportID, s.SportName
ORDER BY RegisteredPlayers DESC, s.SportName;
```

| SportName | RegisteredPlayers |
|---|---:|
| Soccer | 9 |
| Basketball | 6 |
| Baseball | 3 |
| Football | 3 |
| Tennis | 3 |
| Volleyball | 3 |

## Players On The Most Teams

```sql
SELECT CONCAT(p.FirstName, " ", p.LastName) AS PlayerName, COUNT(po.TeamID) AS Teams
FROM Player pl
JOIN Person p ON p.PersonID = pl.PersonID
LEFT JOIN PlaysOn po ON po.PersonID = pl.PersonID
GROUP BY p.PersonID, p.FirstName, p.LastName
ORDER BY Teams DESC, PlayerName
LIMIT 10;
```

| PlayerName | Teams |
|---|---:|
| Aisha Patel | 2 |
| James Walker | 2 |
| Riley Bennett | 2 |
| Sophia Garcia | 2 |
| Amelia Scott | 1 |
| Ava King | 1 |
| Benjamin Green | 1 |
| Charlotte Nelson | 1 |
| Elijah Baker | 1 |
| Emma Davis | 1 |

## Coaches With The Most Teams

```sql
SELECT CONCAT(p.FirstName, " ", p.LastName) AS CoachName, COUNT(cf.TeamID) AS Teams
FROM Coach c
JOIN Person p ON p.PersonID = c.PersonID
LEFT JOIN CoachesFor cf ON cf.PersonID = c.PersonID
GROUP BY p.PersonID, p.FirstName, p.LastName
ORDER BY Teams DESC, CoachName
LIMIT 10;
```

| CoachName | Teams |
|---|---:|
| Rachel Allen | 4 |
| Daniel Hall | 3 |
| Mike Torres | 3 |
| Sarah Johnson | 3 |
| Omar Haddad | 2 |
| Priya Nair | 2 |
| Nina Brooks | 1 |
| Riley Bennett | 1 |

## Average Fee Per Player-Team

```sql
SELECT COUNT(*) AS PlayerTeamFeeRows, ROUND(AVG(AmountOwed), 2) AS AverageFee
FROM FeesOwed;
```

| PlayerTeamFeeRows | AverageFee |
|---:|---:|
| 27 | 140.41 |

## Top Ten Equipment Items

```sql
SELECT ui.ItemName, SUM(eo.Quantity) AS UnitsOrdered,
       ROUND(SUM(eo.Quantity * ui.UnitPrice), 2) AS Revenue
FROM EquipmentOrder eo
JOIN UniformItem ui ON ui.ItemID = eo.ItemID
GROUP BY ui.ItemID, ui.ItemName
ORDER BY UnitsOrdered DESC, ui.ItemName
LIMIT 10;
```

| ItemName | UnitsOrdered | Revenue |
|---|---:|---:|
| Jersey | 28 | 980.00 |
| Water Bottle | 22 | 220.00 |
| Shorts | 15 | 375.00 |
| Socks | 13 | 104.00 |
| Basketball | 9 | 198.00 |
| Shin Guards | 8 | 144.00 |
| Cleats | 7 | 490.00 |
| Warmup Jacket | 7 | 385.00 |
| Glove | 5 | 150.00 |
| Tennis Racket | 5 | 325.00 |
