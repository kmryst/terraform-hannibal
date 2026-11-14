"""観点 request-flow（リクエストの流れ）の図。横長。ALB・ECS・RDS を同じ高さの一直線に置き、各 subnet の中央に置く。

Usage: python3 build_request_flow.py <out.drawio>
要素名・枠名は diagram_common.py の共通定義。観点の表示設定として、CloudFront・ALB・RDS の説明を出さず、
④⑤ と ECS → RDS は短いラベル（SHORT_LABELS）を使う。長いラベルは改行だけする（文言は変えない）。
README 幅 1000px で最小 12px を満たすよう、文字は 20px。
"""
import sys

from diagram_common import Diagram

F = 20
d = Diagram(fs=F, fs_small=F, fs_group=F + 2, hide_desc={"cloudfront", "alb", "rds"}, short_labels=True)

ROW = 420                      # ALB・ECS・RDS・CloudFront・ブラウザの中心の高さ
X_BROWSER, X_MAPBOX = 90, 230
X_AWS, X_CF = 310, 410
X_REG, X_VPC = 510, 680
W_PUB, GAP1, W_APP, GAP2, W_DATA = 190, 135, 200, 135, 200
X_PUB = X_VPC + 20
X_APP = X_PUB + W_PUB + GAP1
X_DATA = X_APP + W_APP + GAP2
X_VPC2 = X_DATA + W_DATA + 20
Y_VPC, Y_SUB = ROW - 165, ROW - 120
H_SUB = 235

d.text("title", "リクエストの流れ（地図表示 1 回分）", 20, 8, 700, 40, F + 6, bold=True)
d.group("aws", X_AWS, ROW - 265, X_VPC2 + 40 - X_AWS, 560)
d.group("region", X_REG, ROW - 245, X_VPC2 + 20 - X_REG, 425, parent="aws")
d.group("vpc", X_VPC, Y_VPC, X_VPC2 - X_VPC, H_SUB + 65, parent="region")
d.group("pub", X_PUB, Y_SUB, W_PUB, H_SUB, parent="vpc")
d.group("app", X_APP, Y_SUB, W_APP, H_SUB, parent="vpc")
d.group("data", X_DATA, Y_SUB, W_DATA, H_SUB, parent="vpc")
d.legend(X_AWS, ROW + 315, w=F * 46)

d.node("mapbox", X_MAPBOX, ROW - 290)
d.node("browser", X_BROWSER, ROW)
d.node("cloudfront", X_CF, ROW, parent="aws")
d.node("route53", X_CF, ROW + 175, parent="aws")
d.node("s3_frontend", (X_REG + X_VPC) / 2, ROW - 150, parent="region")
d.node("alb", X_PUB + W_PUB / 2, ROW, parent="pub", label_width=W_PUB - 20)
d.node("ecs", X_APP + W_APP / 2, ROW, parent="app")
d.node("rds", X_DATA + W_DATA / 2, ROW, parent="data", label_width=W_DATA - 30)


def ry(vid, y):
    _, top, _, h = d.abs[vid]
    return round((y - top) / h, 4)


cf_t = d.abs["cloudfront"][1]
y1, y3 = cf_t + 0.2 * 78, cf_t + 0.8 * 78
xm = (X_BROWSER + 39 + X_AWS) / 2
d.edge("e1", (1, ry("browser", y1)), (0, 0.2), label_at=(xm, y1), label_offset=(0, -26), breaks=("静的ファイル",))
d.edge("e3", (1, ry("browser", y3)), (0, 0.8), label_at=(xm, y3), label_offset=(0, 30), breaks=("GraphQL",))
d.edge("e6", (0.5, 0), (0, 0.5), points=[(X_BROWSER, ROW - 290)], label_at=(X_BROWSER, ROW - 140),
       breaks=("データ",))
y53 = ROW + 175
d.edge("dns", (0, 0.5), (0, 0.5), points=[(25, ROW), (25, y53)], label_at=(170, y53))
ys = d.center("s3_frontend")[1]
d.edge("e2", (0.5, 0), (0, 0.5), points=[(X_CF, ys)], label_at=(X_CF, ROW - 100))
d.edge("e4", (1, 0.5), (0, 0.5), label_at=((X_REG + X_VPC) / 2, ROW), breaks=("GraphQL",))
d.edge("e5", (1, 0.5), (0, 0.5), label_at=(X_PUB + W_PUB + GAP1 / 2, ROW), breaks=("GraphQL",))
d.edge("db", (1, 0.5), (0, 0.5), label_at=(X_APP + W_APP + GAP2 / 2, ROW), breaks=("[PostgreSQL",))

open(sys.argv[1], "w", encoding="utf-8").write(d.xml("request-flow"))
