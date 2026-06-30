import calendar
import json
import os
import time

import matplotlib.pyplot as plt
import pandas as pd
import requests
from pandas.errors import EmptyDataError
from scipy import stats
from sqlalchemy import create_engine

# ========================
# 1. ЗАВАНТАЖЕННЯ ДАНИХ
# ========================
try:
    dataset = pd.read_csv("ecommerce_sales_dataset.csv")
    print(dataset.head())
except FileNotFoundError:
    print("Файл ecommerce_sales_dataset.csv не знайдено.")
except EmptyDataError:
    print("Файл ecommerce_sales_dataset.csv порожній.")

# Висновок:"Виявлена невідповідність між порядком Order_ID та хронологією дат замовлень,
# що може бути характерно для синтетично згенерованих даних. Для анализу часових рядів
# дані відсортовані за датою замовлення."

# ========================
# 2. КОПІЯ ТА СОРТУВАННЯ
# ========================
dataset_clean = dataset.copy()
dataset_clean["Order_Date"] = pd.to_datetime(dataset_clean["Order_Date"])

# Перевірка хронології до виправлення
is_monotonic = dataset_clean.sort_values("Order_ID")[
    "Order_Date"
].is_monotonic_increasing
print(f"Дати зростають разом з ID (до): {is_monotonic}")

# Сортування за датою та перенумерація Order_ID
dataset_clean = dataset_clean.sort_values("Order_Date").reset_index(drop=True)
dataset_clean["Order_ID"] = range(1, len(dataset_clean) + 1)

# Перевірка після виправлення
is_monotonic = dataset_clean["Order_Date"].is_monotonic_increasing
print(f"Дати зростають разом з ID (після): {is_monotonic}")
print(dataset_clean[["Order_ID", "Order_Date"]].head(10))


# Висновок: З метою відповідності бізнес-лозіці реальних e-commerce систем дані
# відсортовані за датою замовлення, після чого Order_ID перепризначений за порядком зростання.
# Це дозволяє коректно інтерпретувати часові ряди і послідовність транзакцій."

# ========================
# 3. ЯКІСТЬ ДАНИХ
# ========================
print("\n=== ЗАГАЛЬНА ІНФОРМАЦІЯ ===")
print(dataset_clean.info())

# Перевірка типів даних
print("\n=== ТИПИ ДАНИХ ===")
print(dataset_clean.dtypes)

print("\n=== ОПИСОВА СТАТИСТИКА КЛЮЧОВИХ КОЛОНОК ===")
key_columns = ["Unit_Price", "Quantity", "Discount", "Profit", "Shipping_Cost"]
print(dataset_clean[key_columns].describe().round(2))

# Виявлено збиткові замовлення.

print("\n=== ПОРОЖНІ ЗНАЧЕННЯ ЗА КОЛОНКАМИ ===")
null_counts = dataset_clean.isnull().sum()
null_percent = (dataset_clean.isnull().sum() / len(dataset_clean) * 100).round(2)
null_df = pd.DataFrame({"Кількість NULL": null_counts, "Відсоток %": null_percent})
print(null_df[null_df["Кількість NULL"] > 0])
if null_counts.sum() == 0:
    print("Порожніх значень не знайдено.")

# Виявлено збиткові замовлення. Підрахунок їх кількості та відсотку від загальної кількості замовлень

# Перевірка дублікатів
print("\n=== ДУБЛІКАТИ ===")
duplicates = dataset_clean.duplicated().sum()
print(f"Кількість дублікатів: {duplicates}")
if duplicates == 0:
    print("Дублікатів не знайдено.")
else:
    dataset_clean = dataset_clean.drop_duplicates()
    print(f"Дублікати видалено. Залишилось рядків: {len(dataset_clean)}")

# Перевірка коректності даних
print("\n=== ПЕРЕВІРКА КОРЕКТНОСТІ ДАНИХ ===")
print(f"Revenue <= 0: {(dataset_clean['Revenue'] <= 0).sum()} рядків")
print(f"Quantity <= 0: {(dataset_clean['Quantity'] <= 0).sum()} рядків")
print(f"Discount > 0.5: {(dataset_clean['Discount'] > 0.5).sum()} рядків")
print(f"Unit_Price <= 0: {(dataset_clean['Unit_Price'] <= 0).sum()} рядків")
print(f"Shipping_Cost < 0: {(dataset_clean['Shipping_Cost'] < 0).sum()} рядків")
print(f"Shipping_Days <= 0: {(dataset_clean['Shipping_Days'] <= 0).sum()} рядків")

# Розподіли ключових числових стовпців
print("\n=== РОЗПОДІЛИ ===")
fig, axes = plt.subplots(2, 3, figsize=(15, 8))
fig.suptitle("Розподіли ключових числових колонок", fontsize=14)

dataset_clean["Unit_Price"].hist(ax=axes[0, 0], bins=30, color="steelblue")
axes[0, 0].set_title("Unit_Price")

dataset_clean["Quantity"].hist(ax=axes[0, 1], bins=10, color="steelblue")
axes[0, 1].set_title("Quantity")

dataset_clean["Discount"].hist(ax=axes[0, 2], bins=10, color="steelblue")
axes[0, 2].set_title("Discount")

dataset_clean["Profit"].hist(ax=axes[1, 0], bins=30, color="steelblue")
axes[1, 0].set_title("Profit")

dataset_clean["Shipping_Cost"].hist(ax=axes[1, 1], bins=30, color="steelblue")
axes[1, 1].set_title("Shipping_Cost")

dataset_clean["Shipping_Days"].hist(ax=axes[1, 2], bins=10, color="steelblue")
axes[1, 2].set_title("Shipping_Days")

plt.tight_layout()
plt.savefig("distributions.png")
plt.show()
print("Графік збережено як distributions.png")

# Гістограми демонструють розподіл ключових числових показників. По осі X — значення показника,
# по осі Y — кількість замовлень.

# =============================
# 4. АНАЛІЗ ЗБИТКОВИХ ЗАМОВЛЕНЬ
# =============================

# Маркування аномалій прапорцем
dataset_clean["is_unprofitable"] = dataset_clean["Profit"] < 0
print(
    f"\nМарковано збиткових замовлень (is_unprofitable=True): {dataset_clean['is_unprofitable'].sum()}"
)

negative_profit = dataset_clean[dataset_clean["Profit"] < 0]
print(f"Збиткових замовлень: {len(negative_profit)}")
print(
    f"Відсоток від загального: {round(len(negative_profit) / len(dataset_clean) * 100, 2)}%"
)

print(
    negative_profit[
        [
            "Order_ID",
            "Country",
            "Category",
            "Unit_Price",
            "Quantity",
            "Discount",
            "Cost",
            "Profit",
            "is_unprofitable",
        ]
    ]
    .sort_values("Profit", ascending=True)
    .head(10)
)

# Висновок: Всі топ-збиткові замовлення мають знижку 0.5 (50%) — максимально можливу.
# Майже всі з  категорії Electronics — дорога категорія з високою собівартістю.
# Велика кількість проданих одиниць (Quantity 3–10) підсилює збиток.
# Збиткові замовлення марковані прапорцем is_unprofitable = True для подальшого аналізу.
# Рекомендації для бизнесу: "Переглянути політику максимальних знижок для категорії Electronics"

# Зв'язок знижки та прибутку
print("\n=== СЕРЕДНІЙ ПРИБУТОК ЗА РІВНЕМ ЗНИЖКИ ===")
print(dataset_clean.groupby("Discount")["Profit"].mean().round(2).sort_index())

# Висновок: Аналіз показав, що застосування знижки більше 30% призводить до збитковості замовлень.
# Максимально допустимий рівень знижки для збереження прибутковості складає 30%.
# Особливо критично для категорії Electronics, де висока собівартість товару суттєво
# збільшує збиток при максимальних знижках.

# Прибуток за категоріями та знижкою
print("\n=== ПРИБУТОК ЗА КАТЕГОРІЯМИ ТА ЗНИЖКОЮ ===")
pivot = dataset_clean.pivot_table(
    values="Profit", index="Category", columns="Discount", aggfunc="mean"
).round(2)
print(pivot)

# ==========================
# 5. ЗБАГАЧЕННЯ ДАНИХ — API
# ==========================

# Верифікація валютної розмірності даних
print(dataset_clean.groupby("Country")["Profit"].mean().round(2))

# Висновок: Перед початком збагачення даних було проведено перевірку середніх значень прибутку
# за країнами. Оскільки середні показники в таких країнах, як Єгипет, Південна Корея та США,
# виявилися в межах одного діапазону (116–216 одиниць), було зроблено висновок, що вихідні
# фінансові показники в датасеті вже нормалізовані в доларах США (USD). Це дозволяє
# використовувати отримані через API курси валют не для конвертації прибутку, а як самостійний
# макроекономічний індикатор для оцінки купівельної спроможності на локальних ринках.

# Словник: країна → код валюти

country_currency = {
    "USA": "USD",
    "UK": "GBP",
    "Germany": "EUR",
    "France": "EUR",
    "Italy": "EUR",
    "Spain": "EUR",
    "Canada": "CAD",
    "Japan": "JPY",
    "China": "CNY",
    "India": "INR",
    "Mexico": "MXN",
    "South Korea": "KRW",
    "Singapore": "SGD",
    "UAE": "AED",
    "Saudi Arabia": "SAR",
    "Egypt": "EGP",
    "Jordan": "JOD",
    "Kuwait": "KWD",
}

dataset_clean["Currency"] = dataset_clean["Country"].map(country_currency)

#  Довідники валют, заповнені "вручну"
pegged_rates = {"AED": 3.6725, "SAR": 3.7500, "JOD": 0.7090, "KWD": 0.3060}
egp_annual = {"2021": 15.70, "2022": 19.20, "2023": 30.90}
egp_2024_monthly = {
    "01": 30.90,
    "02": 30.90,
    "03": 47.20,
    "04": 48.10,
    "05": 47.50,
    "06": 47.80,
    "07": 48.20,
    "08": 48.50,
    "09": 48.30,
    "10": 48.60,
    "11": 49.10,
    "12": 49.50,
}

frankfurter_currencies = ["GBP", "EUR", "CAD", "JPY", "CNY", "INR", "MXN", "KRW", "SGD"]
cache_file = "rate_cache.json"
rate_cache = {}

# Перевірка: якщо файл кешу існує - завантажуємо його, якщо ні - робимо запит до API
if os.path.exists(cache_file):
    with open(cache_file, "r", encoding="utf-8") as f:
        rate_cache = json.load(f)
    print(f"Кеш завантажений з файлу {cache_file}. Запити до API не потрібні.")
else:
    print("Файл кешу не знайдено. Початок збору даних через API (48 месяцев)...")

    for year in range(2021, 2025):
        for month in range(1, 13):
            month_str = f"{month:02d}"
            year_month = f"{year}-{month_str}"
            last_day = calendar.monthrange(year, month)[1]
            date_str = f"{year}-{month_str}-{last_day:02d}"

            # 1. Отримання даних з API для основних валют
            url = f"https://api.frankfurter.app/{date_str}"
            params = {"from": "USD", "to": ",".join(frankfurter_currencies)}

            try:
                resp = requests.get(url, params=params)
                if resp.status_code == 200:
                    data = resp.json()
                    rates = data["rates"]

                    # 2. Додавання до кешу "ручних" валют для цієї дати
                    # Пегі (фіксовані)
                    for c, r in pegged_rates.items():
                        rates[c] = r

                    # Єгипет (динамічний/річний)
                    if year == 2024:
                        rates["EGP"] = egp_2024_monthly.get(
                            month_str, 47.50
                        )  # страхування на випадок відсутності даних
                    else:
                        rates["EGP"] = egp_annual.get(str(year), 30.90)

                    rate_cache[year_month] = rates
                else:
                    print(f"Помилка API на даті {date_str}: {resp.status_code}")
            except Exception as e:
                print(f"Помилка запиту: {e}")

            time.sleep(0.5)  # Пауза, щоб API не заблокував

    # Збереження зібраного кешу
    with open(cache_file, "w", encoding="utf-8") as f:
        json.dump(rate_cache, f, ensure_ascii=False)
    print(f"Збір завершений. Дані збережені в {cache_file}")

# =========================================
# 6. ДОДАВАННЯ КОЛОНОК (використовуючи кеш)
# =========================================


def get_rate(row):
    currency = row["Currency"]
    if currency == "USD":
        return 1.0
    year_month = row["Order_Date"].strftime("%Y-%m")
    month_data = rate_cache.get(year_month)
    if month_data:
        return month_data.get(currency)
    return None


dataset_clean["Exchange_Rate_USD"] = dataset_clean.apply(get_rate, axis=1)

print(f"\nПропусків в курсах: {dataset_clean['Exchange_Rate_USD'].isnull().sum()}")
print(dataset_clean[["Country", "Currency", "Exchange_Rate_USD"]].head(10))

# ==========================
# 7. ЗБЕРЕЖЕННЯ В PostgreSQL
# ==========================
engine = create_engine("postgresql://postgres:********@localhost:5432/diploma_project")

try:
    with engine.connect() as conn:
        print("\nПідключення до PostgreSQL успішне.")
except Exception as e:
    print(f"Помилка підключення: {e}")
    exit()

# Збереження датасету в PostgreSQL
dataset_clean.to_sql("ecommerce_sales", engine, if_exists="replace", index=False)
print("Дані збережено в таблицю ecommerce_sales")
print(f"Рядків завантажено: {len(dataset_clean)}")


# ============================================
# 8. КОРЕЛЯЦІЙНИЙ АНАЛІЗ ТА ТЕСТУВАННЯ ГІПОТЕЗ
# ============================================

# Агрегація даних по країнах для кореляційного аналізу

country_stats = (
    dataset_clean.groupby("Country")
    .agg(
        total_orders=("Order_ID", "count"),
        avg_discount=("Discount", "mean"),
        avg_shipping_cost=("Shipping_Cost", "mean"),
        avg_exchange_rate=("Exchange_Rate_USD", "mean"),
        total_revenue=("Revenue", "sum"),
        avg_profit=("Profit", "mean"),
    )
    .round(2)
    .reset_index()
)

print(country_stats)

# Кореляційна матриця
correlation_matrix = (
    country_stats[
        [
            "total_orders",
            "avg_discount",
            "avg_shipping_cost",
            "avg_exchange_rate",
            "total_revenue",
            "avg_profit",
        ]
    ]
    .corr()
    .round(2)
)

print("\n=== КОРЕЛЯЦІЙНА МАТРИЦЯ ===")
print(correlation_matrix)

# Візуалізація

plt.figure(figsize=(10, 8))
plt.title("Кореляційна матриця показників по країнах", fontsize=14, pad=15)
im = plt.imshow(correlation_matrix, cmap="coolwarm", aspect="auto", vmin=-1, vmax=1)
plt.colorbar(im)
labels = ["Замовлення", "Знижка", "Доставка", "Курс валюти", "Виручка", "Прибуток"]
plt.xticks(range(len(labels)), labels, rotation=45, ha="right")
plt.yticks(range(len(labels)), labels)
for i in range(len(correlation_matrix)):
    for j in range(len(correlation_matrix)):
        plt.text(
            j,
            i,
            str(correlation_matrix.iloc[i, j]),
            ha="center",
            va="center",
            fontsize=10,
        )
plt.tight_layout()
plt.savefig("correlation_matrix.png")
plt.show()
print("Графік збережено як correlation_matrix.png")

# H1: Знижка vs Кількість замовлень по країнах

x = country_stats["avg_discount"]
y = country_stats["total_orders"]

correlation, p_value = stats.pearsonr(x, y)

regions = dataset_clean.groupby("Country")["Region"].first()
country_stats["Region"] = country_stats["Country"].map(regions)

colors = {
    "Asia": "steelblue",
    "Europe": "coral",
    "Middle East": "green",
    "North America": "purple",
}

plt.figure(figsize=(8, 6))
for region, group in country_stats.groupby("Region"):
    plt.scatter(
        group["avg_discount"],
        group["total_orders"],
        color=colors[region],
        label=region,
        s=100,
    )

plt.xlabel("Середня знижка")
plt.ylabel("Кількість замовлень")
plt.title(
    f"H1: Знижка vs Кількість замовлень\nr={correlation:.2f}, p-value={p_value:.4f}"
)
plt.legend()
plt.tight_layout()
plt.savefig("h1_discount_orders.png")
plt.show()
print(f"Кореляція: {correlation:.2f}, p-value: {p_value:.4f}")

# Гіпотеза H1: Знижка впливає на кількість замовлень.
# Кореляція Пірсона: -0.30, p-value: 0.2287.
# Висновок: помірна негативна кореляція — більша знижка корелює з меншою кількістю замовлень.
# Результат статистично незначущий (p > 0.05). Візуально помітно що європейські країни отримали
# найвищі знижки при найменшій кількості замовлень, тоді як Північна Америка, як домашній регіон
# бренду, демонструє найбільшу кількість замовлень при найменшій середній знижці.
# Таким чином, підтверджується висновок про неефективність знижок як інструменту стимулювання
# попиту.

# H2: Вартість доставки vs Кількість замовлень по країнах

x = country_stats["avg_shipping_cost"]
y = country_stats["total_orders"]

correlation, p_value = stats.pearsonr(x, y)

plt.figure(figsize=(8, 6))
for region, group in country_stats.groupby("Region"):
    plt.scatter(
        group["avg_shipping_cost"],
        group["total_orders"],
        color=colors[region],
        label=region,
        s=100,
    )

plt.xlabel("Середня вартість доставки")
plt.ylabel("Кількість замовлень")
plt.title(
    f"H2: Вартість доставки vs Кількість замовлень\nr={correlation:.2f}, p-value={p_value:.4f}"
)
plt.legend()
plt.tight_layout()
plt.savefig("h2_shipping_orders.png")
plt.show()
print(f"Кореляція: {correlation:.2f}, p-value: {p_value:.4f}")

# Гіпотеза H2: Вартість доставки впливає на кількість замовлень.
# Кореляція Пірсона: -0.14, p-value: 0.5735.
# Висновок: кореляція між вартістю доставки та кількістю замовлень відсутня (r=-0.14, p>0.05).
# Це є характерною особливістю синтетичного датасету з єдиною фіксованою ціновою політикою
# доставки по всіх регіонах. В умовах реального бізнесу вартість доставки є суттєвим фактором
# прийняття рішення про покупку.


# H3: Зміна курсу валюти vs Кількість замовлень

# Для коректного аналізу впливу курсу валюти на кількість замовлень використано не абсолютне
# значення курсу, а темп його зміни за період 2021-2024. Це дозволяє порівнювати країни з
# різними валютами в єдиній відносній шкалі. Наприклад, єгипетський фунт (+180%) та
# південнокорейська вона (+16%) стають порівнянними показниками нестабільності валюти.
# Країни з фіксованим курсом (UAE, Kuwait, Saudi Arabia, Jordan, USA) мають значення 0%.

# Розрахунок волатильності (зміни) курсу по країнах
currency_volatility = (
    dataset_clean.groupby(["Country", dataset_clean["Order_Date"].dt.year])[
        "Exchange_Rate_USD"
    ]
    .mean()
    .unstack()
)

# Зміна курсу 2021 → 2024 у відсотках
currency_volatility["rate_change_pct"] = (
    (currency_volatility[2024] - currency_volatility[2021])
    / currency_volatility[2021]
    * 100
).round(2)

print(
    currency_volatility[["rate_change_pct"]].sort_values(
        "rate_change_pct", ascending=False
    )
)

# Візуалізація
country_stats["rate_change_pct"] = country_stats["Country"].map(
    currency_volatility["rate_change_pct"]
)

x = country_stats["rate_change_pct"]
y = country_stats["total_orders"]

correlation, p_value = stats.pearsonr(x, y)

plt.figure(figsize=(8, 6))
for region, group in country_stats.groupby("Region"):
    plt.scatter(
        group["rate_change_pct"],
        group["total_orders"],
        color=colors[region],
        label=region,
        s=100,
    )

plt.xlabel("Зміна курсу валюти 2021→2024 (%)")
plt.ylabel("Кількість замовлень")
plt.title(
    f"H3: Волатильність курсу vs Кількість замовлень\nr={correlation:.2f}, p-value={p_value:.4f}"
)
plt.axvline(x=0, color="gray", linestyle="--", alpha=0.5)
plt.legend()
plt.tight_layout()
plt.savefig("h3_volatility_orders.png")
plt.show()
print(f"Кореляція: {correlation:.2f}, p-value: {p_value:.4f}")

# Гіпотеза H3: Зміна курсу валюти впливає на кількість замовлень.
# Кореляція Пірсона: -0.22, p-value: 0.3909
# Висновок: слабка негативна кореляція — девальвація національної валюти корелює зі зменшенням
# кількості замовлень. Результат статистично незначущий (p > 0.05) через малу вибірку (18 країн).
# Проте напрямок зв'язку підтверджується кейсом Єгипту — найбільша девальвація (+180%)
# супроводжувалась найбільшим падінням замовлень у 2024 році (-47%).

# ЗАГАЛЬНИЙ ВИСНОВОК КОРЕЛЯЦІЙНОГО АНАЛІЗУ:
# Тестування трьох гіпотез на рівні 18 країн показало статистично незначущі
# результати (p > 0.05) через малу вибірку, проте напрямки зв'язків є логічними:
# H1: знижки негативно корелюють з кількістю замовлень (r=-0.30) —
#     більша знижка не стимулює попит
# H2: вартість доставки не впливає на кількість замовлень (r=-0.14) —
#     характерно для синтетичного датасету з фіксованою ціною доставки
# H3: девальвація валюти негативно корелює з кількістю замовлень (r=-0.22) —
#     підтверджується кейсом Єгипту (-47% замовлень при +180% девальвації)
# Для статистично значущих результатів необхідна більша вибірка країн.
#
# Стратегічні висновки для міжнародної експансії:
# 1. Знижкова політика має бути диференційованою — не однакова для всіх,
#    а інструментом програми лояльності для утримання VIP та Premium сегментів
#    та розпродажу складських залишків. Знижки понад 30% є економічно
#    невиправданими та не повинні застосовуватись як інструмент масового
#    стимулювання попиту.
# 2. Вартість доставки має враховувати географічну віддаленість ринку.
#    В умовах енергетичної кризи, алгоритмічної локалізації пошукових систем
#    та здорожчання міжнародної логістики пріоритет мають отримати найближчі
#    географічні ринки. Для ринків з високим потенціалом доцільно розглянути
#    створення регіональних фулфілмент-центрів як інструмент зниження вартості
#    та термінів доставки і підвищення конкурентоспроможності бренду.
# 3. Стратегія експансії має пріоритизувати ринки зі стабільною валютою —
#    вони демонструють вищу маржинальність та нижчу збитковість.
