"""Economy simulation for Phase 7C audit."""
import math

BUILDINGS = [
    ('Corner Dealer',      10.0,           0.10,    1.15),
    ('Protection Racket',  150.0,          0.60,    1.18),
    ('Chop Shop',          2_000.0,        3.50,    1.18),
    ('Sports Betting',     20_000.0,       20.0,    1.18),
    ('Pawn Shop',          150_000.0,      100.0,   1.18),
    ('Loan Shark',         1_200_000.0,    500.0,   1.20),
    ('Casino',             10_000_000.0,   2_500.0, 1.20),
    ('Nightclub',          80_000_000.0,   12_000.0,1.20),
    ('Dock',               600_000_000.0,  60_000.0,1.20),
    ('Arms Broker',        5_000_000_000.0,300_000.0,1.20),
    ('HQ',                 40_000_000_000.0,1_500_000.0,1.20),
]

MANAGERS = [20_000, 150_000, 750_000, 4_000_000, 20_000_000,
            60_000_000, 500_000_000, 4_000_000_000, 30_000_000_000,
            250_000_000_000, 2_000_000_000_000]

RANK_THRESHOLDS = [0, 1, 5, 12, 25, 45, 75, 115, 165, 230, 310]


def building_cost(base, scale, owned):
    return base * (scale ** owned)


def income_per_sec(owned_list, manager_hired, prestige_tokens=0):
    total = 0.0
    for i, (n, bc, bi, bs) in enumerate(BUILDINGS):
        o = owned_list[i]
        inc = bi * o
        if manager_hired[i]:
            inc *= 1.5
        total += inc
    total *= (1.02 ** prestige_tokens)
    return total


balance = 0.0
lifetime = 0.0
owned = [1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
manager_hired = [False] * 11
prestige_tokens = 0

milestones = {
    'first_manager':   None,
    'first_territory': None,
    'first_rival':     None,
    'crew_member':     None,
    'associate':       None,
    'made_man':        None,
    'capo':            None,
    'boss':            None,
}

income_snapshots = {600: None, 1800: None, 3600: None, 7200: None}

CLICK_RATE = 5.0 / 60.0
CLICK_VALUE = 1.0
TOKEN_EARN_INTERVAL = 300.0
next_token_earn = TOKEN_EARN_INTERVAL
territory_mult = 1.0

for step in range(0, 7201):
    time = float(step)

    ips = income_per_sec(owned, manager_hired, prestige_tokens)
    ips_with_territory = ips * territory_mult
    passive = ips_with_territory
    balance += passive
    lifetime += passive

    click_inc = CLICK_VALUE * (1.02 ** prestige_tokens) * CLICK_RATE
    balance += click_inc
    lifetime += click_inc

    if owned[5] > 0:
        effective_offices = min(owned[5], 2)
        interest = balance * (0.0005 / 60.0) * effective_offices
        balance += interest
        lifetime += interest

    next_token_earn -= 1.0
    if next_token_earn <= 0:
        prestige_tokens += 1
        next_token_earn = TOKEN_EARN_INTERVAL + prestige_tokens * 60

        if prestige_tokens >= 10 and territory_mult < 1.15:
            territory_mult = 1.15
        elif prestige_tokens >= 25 and territory_mult < 1.27:
            territory_mult = 1.27
        elif prestige_tokens >= 50 and territory_mult < 1.47:
            territory_mult = 1.47
        elif prestige_tokens >= 100 and territory_mult < 1.82:
            territory_mult = 1.82

        if prestige_tokens == 1 and milestones['crew_member'] is None:
            milestones['crew_member'] = time / 60.0
        if prestige_tokens == 5 and milestones['associate'] is None:
            milestones['associate'] = time / 60.0
        if prestige_tokens == 12 and milestones['made_man'] is None:
            milestones['made_man'] = time / 60.0
        if prestige_tokens == 25 and milestones['capo'] is None:
            milestones['capo'] = time / 60.0
        if prestige_tokens == 75 and milestones['boss'] is None:
            milestones['boss'] = time / 60.0

    best_idx = -1
    best_ratio = 0.0
    for i, (n, bc, bi, bs) in enumerate(BUILDINGS):
        cost = building_cost(bc, bs, owned[i])
        if cost <= balance:
            ratio = bi / cost
            if ratio > best_ratio:
                best_ratio = ratio
                best_idx = i

    if best_idx >= 0:
        (n, bc, bi, bs) = BUILDINGS[best_idx]
        cost = building_cost(bc, bs, owned[best_idx])
        balance -= cost
        owned[best_idx] += 1

    for i in range(11):
        if not manager_hired[i] and balance >= MANAGERS[i]:
            if prestige_tokens >= RANK_THRESHOLDS[min(i, len(RANK_THRESHOLDS) - 1)]:
                balance -= MANAGERS[i]
                manager_hired[i] = True
                if milestones['first_manager'] is None:
                    milestones['first_manager'] = time / 60.0

    if prestige_tokens >= 10 and milestones['first_territory'] is None:
        milestones['first_territory'] = time / 60.0

    if prestige_tokens >= 8 and milestones['first_rival'] is None:
        milestones['first_rival'] = time / 60.0

    current_ips = income_per_sec(owned, manager_hired, prestige_tokens) * territory_mult
    for t2, v in income_snapshots.items():
        if v is None and time >= t2:
            income_snapshots[t2] = current_ips


def fmt(n):
    if n >= 1e12:
        return f'${n/1e12:.2f}T/s'
    if n >= 1e9:
        return f'${n/1e9:.2f}B/s'
    if n >= 1e6:
        return f'${n/1e6:.2f}M/s'
    if n >= 1e3:
        return f'${n/1e3:.2f}K/s'
    return f'${n:.2f}/s'


def fmt_bal(n):
    if n >= 1e12:
        return f'${n/1e12:.2f}T'
    if n >= 1e9:
        return f'${n/1e9:.2f}B'
    if n >= 1e6:
        return f'${n/1e6:.2f}M'
    if n >= 1e3:
        return f'${n/1e3:.2f}K'
    return f'${n:.2f}'


print('=== PROGRESSION MILESTONES ===')
for k, v in milestones.items():
    if v is not None:
        print(f'  {k:20s}: {v:.1f} min')
    else:
        print(f'  {k:20s}: not reached in 2h')

print()
print('=== INCOME SNAPSHOTS ===')
labels = {600: '10 min', 1800: '30 min', 3600: '60 min', 7200: '120 min'}
for t2, v in income_snapshots.items():
    lbl = labels[t2]
    print(f'  After {lbl}: {fmt(v) if v else "N/A"}')

print()
print('=== FINAL STATE (2h) ===')
print(f'  Prestige tokens: {prestige_tokens}')
print(f'  Buildings:')
for i, (n, bc, bi, bs) in enumerate(BUILDINGS):
    if owned[i] > 0:
        print(f'    {n}: x{owned[i]}  (mgr: {"YES" if manager_hired[i] else "no"})')
print(f'  Managers hired:  {sum(manager_hired)}/11')
print(f'  Balance:         {fmt_bal(balance)}')
print(f'  Territory mult:  x{territory_mult:.2f}')
print(f'  IPS final:       {fmt(income_per_sec(owned, manager_hired, prestige_tokens) * territory_mult)}')

# Income source breakdown
print()
print('=== INCOME SOURCE BREAKDOWN (final) ===')
total_ips = income_per_sec(owned, manager_hired, prestige_tokens)
for i, (n, bc, bi, bs) in enumerate(BUILDINGS):
    if owned[i] > 0:
        contrib = bi * owned[i] * (1.5 if manager_hired[i] else 1.0)
        pct = contrib / total_ips * 100 if total_ips > 0 else 0
        print(f'  {n:25s}: {fmt(contrib):>15s}  ({pct:.1f}%)')
