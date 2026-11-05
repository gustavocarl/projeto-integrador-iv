"""Gera planilhas de exemplo de vendas de tecnologia (um arquivo por mês), no modelo da importação.

Uso (precisa do openpyxl):
    python gerar_vendas_tecnologia.py

Cada mês tem semente fixa: rodar de novo gera os mesmos arquivos. Os meses têm sazonalidade
(janeiro: volta às aulas; julho: férias) e preços de 2025 menores, para o comparativo de meses
mostrar diferenças.
"""

import calendar
import random
from datetime import date
from pathlib import Path

from openpyxl import Workbook
from openpyxl.styles import Alignment, Font, PatternFill

# (nome, SKU, preço de 2026, peso nas vendas, quantidade máxima por venda, grupo)
CATALOG = [
    ("iPhone 15 128GB", "IPH-015", 4999.00, 3, 1, "phone"),
    ("Smartphone Galaxy A55 128GB", "SMA-A55", 1899.00, 7, 2, "phone"),
    ("Notebook Ideapad 3 i5 8GB", "NTB-IP3", 3299.00, 4, 1, "school"),
    ("Tablet Galaxy Tab A9", "TAB-A9", 1099.00, 4, 2, "school"),
    ("Console PlayStation 5 Slim", "PS5-SLM", 3799.00, 3, 1, "games"),
    ("Controle DualSense", "CTR-DSN", 449.00, 3, 2, "games"),
    ('Smart TV 50" 4K', "TV-50K", 2299.00, 2, 1, "tv"),
    ('Monitor 24" Full HD 75Hz', "MON-24F", 799.00, 5, 2, "school"),
    ("SSD NVMe 1TB", "SSD-1TB", 449.90, 6, 2, "pc"),
    ("Teclado Mecânico Redragon Kumara", "TEC-KUM", 229.90, 5, 2, "pc"),
    ("Mouse Sem Fio Logitech M280", "MOU-280", 79.90, 9, 4, "school"),
    ("Webcam Full HD 1080p", "WEB-1080", 189.90, 4, 2, "pc"),
    ("Roteador Wi-Fi 6 AX1500", "ROT-AX15", 399.00, 4, 1, "pc"),
    ("Fone Bluetooth JBL Tune 520", "FON-520", 249.90, 10, 3, "audio"),
    ("Caixa de Som Bluetooth JBL Go 4", "CXS-GO4", 299.00, 5, 2, "audio"),
    ("Smartwatch Amazfit Bip 5", "SWT-BP5", 499.00, 7, 2, "wear"),
    ("Carregador Turbo USB-C 25W", "CAR-25W", 89.90, 11, 4, "acc"),
    ("Cabo USB-C 1m", "CAB-USC", 29.90, 9, 5, "acc"),
    ("Pen Drive 64GB", "PEN-064", 39.90, 8, 5, "school"),
]

# Online: (marketplace ou None = loja virtual própria, peso)
MARKETPLACES = [
    (None, 30), ("Mercado Livre", 19), ("Amazon", 17), ("KaBuM!", 13),
    ("Shopee", 9), ("Magalu", 7), ("Casas Bahia", 6),
]

DISCOUNTS = [(0.00, 60), (0.05, 25), (0.10, 15)]

# Mês -> (semente, nº de vendas, fator de preço sobre 2026, % presencial, grupos em alta)
MONTHS = {
    (2025, 1): (2501, 118, 0.92, 0.22, {"school": 2.2}),
    (2025, 7): (2507, 126, 0.95, 0.26, {"games": 2.0, "tv": 2.0, "wear": 1.4}),
    (2026, 1): (2601, 142, 1.00, 0.24, {"school": 2.3, "phone": 1.2}),
    (2026, 9): (2609, 150, 1.00, 0.23, {"phone": 1.6, "audio": 1.3}),
}

MONTH_NAMES = ["janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho",
               "agosto", "setembro", "outubro", "novembro", "dezembro"]


def list_price(price_2026: float, factor: float) -> float:
    """Preço do ano, terminando em ,90 (ou inteiro, se o de 2026 for inteiro)."""
    value = price_2026 * factor
    if price_2026 == int(price_2026):
        return float(round(value))
    return round(int(value) + 0.90, 2)


def generate(year: int, month: int) -> list[tuple]:
    seed, count, factor, in_person, boosts = MONTHS[(year, month)]
    rng = random.Random(seed)
    days = calendar.monthrange(year, month)[1]

    # Fins de semana vendem mais.
    day_weights = [1.5 if date(year, month, d).weekday() >= 5 else 1.0 for d in range(1, days + 1)]
    product_weights = [w * boosts.get(group, 1.0) for (_, _, _, w, _, group) in CATALOG]

    rows = []
    for _ in range(count):
        day = rng.choices(range(1, days + 1), day_weights)[0]
        name, sku, price, _, max_qty, _ = rng.choices(CATALOG, product_weights)[0]
        expensive = price >= 1000
        quantity = 1 if expensive and rng.random() < 0.85 else rng.randint(1, max_qty)
        discount = rng.choices([d for d, _ in DISCOUNTS], [w for _, w in DISCOUNTS])[0]
        unit = round(list_price(price, factor) * (1 - discount), 2)
        if rng.random() < in_person:
            channel, marketplace = "Presencial", None
        else:
            channel = "Online"
            marketplace = rng.choices([m for m, _ in MARKETPLACES], [w for _, w in MARKETPLACES])[0]
        rows.append((date(year, month, day), name, sku, quantity, unit, channel, marketplace))

    rows.sort(key=lambda r: (r[0], r[1]))
    return rows


def write(path: Path, rows: list[tuple]) -> None:
    wb = Workbook()
    ws = wb.active
    ws.title = "Vendas"
    ws.append(["Data", "Produto", "SKU", "Quantidade", "Preço Unitário", "Canal", "Marketplace"])
    for row in rows:
        ws.append(list(row))

    header_fill = PatternFill("solid", fgColor="1F3864")
    for cell in ws[1]:
        cell.font = Font(bold=True, color="FFFFFF")
        cell.fill = header_fill
        cell.alignment = Alignment(horizontal="center")
    for row in ws.iter_rows(min_row=2):
        row[0].number_format = "dd/mm/yyyy"
        row[3].number_format = "0"
        row[4].number_format = '"R$" #,##0.00'
    for col, width in zip("ABCDEFG", [12, 36, 12, 12, 16, 12, 16]):
        ws.column_dimensions[col].width = width
    ws.freeze_panes = "A2"
    ws.auto_filter.ref = f"A1:G{ws.max_row}"
    wb.save(path)


def main() -> None:
    folder = Path(__file__).parent
    for year, month in MONTHS:
        rows = generate(year, month)
        path = folder / f"vendas-tecnologia-{year}-{month:02d}.xlsx"
        write(path, rows)
        revenue = sum(r[3] * r[4] for r in rows)
        items = sum(r[3] for r in rows)
        total = f"{revenue:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")
        print(f"{path.name}: {MONTH_NAMES[month - 1]}/{year}, {len(rows)} vendas, {items} itens, R$ {total}")


if __name__ == "__main__":
    main()
