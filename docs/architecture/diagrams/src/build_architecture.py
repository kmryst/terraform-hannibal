"""全体図（検証の正本）: request-flow と operations の両方の要素・接続を 1 枚に描く。

Usage: python3 build_architecture.py <out.drawio>
"""
import sys

from diagram_common import Diagram

d = Diagram(fs=14, fs_small=12, fs_group=16)

# ---- 枠 ----
d.text("title", "terraform-hannibal の AWS 構成（全体図: リクエストの流れ・デプロイ・監視・監査・Game Day・バックアップ）",
       20, 14, 1400, 40, 22, bold=True)
d.legend(1700, 12)
d.group("aws", 340, 80, 2150, 1500)
d.group("region", 800, 330, 1660, 1230, parent="aws")
d.group("vpc", 1120, 580, 1270, 340, parent="region")
d.group("pub", 1145, 620, 325, 270, parent="vpc")
d.group("app", 1495, 620, 595, 270, parent="vpc")
d.group("data", 2115, 620, 250, 270, parent="vpc")

ROW = 721 + 0.3 * 78  # CloudFront の右 0.3 の高さ = ALB・ECS・RDS の中心

# ---- AWS の外 ----
d.node("gha", 150, 290)
d.node("browser", 150, 760)
d.node("mapbox", 150, 1060)
d.node("dev", 150, 1270)
d.node("email", 2580, 1270)
# ---- AWS Cloud（Region の外） ----
d.node("sts", 480, 470, parent="aws")
d.node("route53", 480, 620, parent="aws")
d.node("cloudfront", 640, 760, parent="aws")
# ---- Region ----
d.node("s3_frontend", 1040, 440, parent="region")
d.node("s3_codedeploy", 1240, 440, parent="region")
d.node("codedeploy", 1560, 440, parent="region")
d.node("ecr", 2060, 440, parent="region")
d.node("alb", 1360, ROW, parent="pub")
d.node("ecs", 1800, ROW, parent="app")
d.node("rds", 2240, ROW, parent="data")
d.node("s3_canary", 860, 1010, parent="region")
d.node("canary", 1050, 1010, parent="region")
d.node("secrets", 1580, 1010, parent="region")
d.node("logs", 1880, 1010, parent="region")
d.node("fis", 1740, 1270, parent="region")
d.node("alarm", 2100, 1270, parent="region")
d.node("sns", 2300, 1270, parent="region")
# foundation の監査系（2026-11-14 ユーザー決定）。Region の下の段に横一列
YA = 1460
d.node("s3_athena", 900, YA, parent="region")
d.node("athena", 1120, YA, parent="region")
d.node("s3_cloudtrail", 1340, YA, parent="region")
d.node("cloudtrail", 1560, YA, parent="region")
d.node("logs_cloudtrail", 1780, YA, parent="region")


def ry(vid, y):
    _, top, _, h = d.abs[vid]
    return round((y - top) / h, 4)


def rx(vid, x):
    left, _, w, _ = d.abs[vid]
    return round((x - left) / w, 4)


cf_l, cf_t = d.abs["cloudfront"][:2]
# ---- 番号付きの流れ ----
y1, y3 = cf_t + 0.3 * 78, cf_t + 0.7 * 78
d.edge("e1", (1, ry("browser", y1)), (0, 0.3), label_at=(265, y1))
d.edge("e3", (1, ry("browser", y3)), (0, 0.7), label_at=(470, y3))
yb6 = d.port("browser", 1, 0.95)[1]
d.edge("e6", (1, 0.95), (1, 0.5), points=[(260, yb6), (260, 1060)], label_at=(260, 930))
x2 = d.port("cloudfront", 0.7, 0)[0]
d.edge("e2", (0.7, 0), (0, 0.5), points=[(x2, 440)], label_at=(740, 440))
d.edge("e4", (1, 0.3), (0, 0.5), label_at=(940, ROW))
d.edge("e5", (1, 0.5), (0, 0.5), label_at=(1600, ROW))
# ---- 要求の流れ（番号なし） ----
d.edge("dns", (0.5, 0), (0, 0.5), points=[(150, 620)], label_at=(150, 672))
d.edge("db", (1, 0.5), (0, 0.5), label_at=(1990, ROW))

# ---- GitHub Actions（右 3 本はそのまま右へ、上・左の 6 本は上のレーンへ） ----
gy = lambda r: d.port("gha", 1, r)[1]
gx = lambda r: d.port("gha", r, 0)[0]
xinv = d.port("cloudfront", 0.3, 0)[0]
d.edge("sync", (1, 0.2), (0.5, 0), points=[(1040, gy(0.2))], label_at=(1040, 368))
d.edge("inval", (1, 0.6), (0.3, 0), points=[(xinv, gy(0.6))], label_at=(xinv, 335))
d.edge("oidc", (1, 0.8), (0.5, 0), points=[(480, gy(0.8))], label_at=(480, 385))
d.edge("tf", (1, 0.4), (0, ry("region", 390)), points=[(740, gy(0.4)), (740, 390)], label_at=(740, 345))
xcr = d.port("canary", 0.7, 0)[0]
d.edge("canaryruns", (0.5, 0), (0.7, 0), points=[(gx(0.5), 210), (1100, 210), (1100, 930), (xcr, 930)],
       label_at=(1100, 553))
d.edge("appspec", (0.25, 0), (0.5, 0), points=[(gx(0.25), 185), (1240, 185)], label_at=(1240, 280))
d.edge("deploy", (0, 0.25), (0.5, 0), points=[(90, gy(0.25)), (90, 160), (1560, 160)], label_at=(1560, 280))
d.edge("taskdef", (0, 0.5), (0.5, 0), points=[(70, gy(0.5)), (70, 135), (1800, 135)], label_at=(1800, 220))
d.edge("push", (0, 0.75), (0.5, 0), points=[(50, gy(0.75)), (50, 110), (2060, 110)], label_at=(2060, 280))

# ---- CodeDeploy ----
cdy = lambda r: d.port("codedeploy", 0, r)[1]
d.edge("cd_s3", (0, 0.3), (1, 0.3), label_at=(1400, cdy(0.3)))
d.edge("cd_alb", (0, 0.85), (0.5, 0), points=[(1360, cdy(0.85))], label_at=(1360, 548))
xe15 = d.port("ecs", 0.15, 0)[0]
d.edge("cd_ecs", (1, 0.85), (0.15, 0), points=[(xe15, cdy(0.85))], label_at=(1686, cdy(0.85)))
xcd8 = d.port("codedeploy", 0.8, 0)[0]
xal7 = d.port("alarm", 0.7, 0)[0]
d.edge("cd_alarm", (0.8, 0), (0.7, 0), points=[(xcd8, 308), (2425, 308), (2425, 1150), (xal7, 1150)],
       label_at=(2290, 1150))

# ---- ECS の task execution role の通信 ----
ey = lambda r: d.port("ecs", 1, r)[1]
d.edge("pull", (1, 0.2), (0, 0.5), points=[(1860, ey(0.2)), (1860, 440)], label_at=(1940, 440))
d.edge("secret", (0, 0.75), (1, 0.5), points=[(1720, ey(0.75)), (1720, 1010)], label_at=(1670, 1010))
d.edge("applog", (1, 0.9), (0.5, 0), points=[(1880, ey(0.9))], label_at=(1880, 950))

# ---- 監視・通知 ----
cy_ = lambda r: d.port("canary", 0, r)[1]
xc3 = d.port("canary", 0.3, 0)[0]
d.edge("monitor", (0.3, 0), (1, 0.9), points=[(xc3, d.port("cloudfront", 1, 0.9)[1])], label_at=(905, d.port("cloudfront", 1, 0.9)[1]))
d.edge("artifacts", (0, 0.5), (1, 0.5), label_at=(955, 1010))
xal3 = d.port("alarm", 0.3, 0)[0]
d.edge("metric", (1, 0.85), (0.3, 0), points=[(1200, cy_(0.85)), (1200, 1170), (xal3, 1170)], label_at=(1440, 1170))
d.edge("notify", (1, 0.5), (0, 0.5), label_at=(2200, 1270))
d.edge("mail", (1, 0.5), (0, 0.5), label_at=(2410, 1270))

# ---- Game Day ----
d.edge("gameday", (1, 0.5), (0, 0.5), label_at=(570, 1270))
d.edge("stoptask", (0.5, 0), (0, 0.95), points=[(1740, ey(0.95))], label_at=(1740, 1120))
d.edge("stopcond", (1, 0.5), (0, 0.5), label_at=(1920, 1270))

# ---- 監査 ----
d.edge("athena_result", (0, 0.5), (1, 0.5), label_at=(1010, YA))
d.edge("athena_query", (1, 0.5), (0, 0.5), label_at=(1230, YA))
d.edge("trail_s3", (0, 0.5), (1, 0.5), label_at=(1450, YA))
d.edge("trail_logs", (1, 0.5), (0, 0.5), label_at=(1670, YA))

open(sys.argv[1], "w", encoding="utf-8").write(d.xml("architecture"))
