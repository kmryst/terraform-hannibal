"""観点 operations（デプロイ・監視・監査・Game Day・バックアップ）の図。横長（README 幅 1000px で最小 12px）。

Usage: python3 build_operations.py <out.drawio>
要素・枠名・ラベルは diagram_common.py の共通定義をそのまま使う。観点の表示設定として、CloudFront の説明を出さず、
ALB は短い説明（SHORT_DESCS: target group だけ）を使う。

GitHub Actions からの線は 4 本に束ねる（ユーザーの決定）:
  ① AWS STS（oidc）、② Region 枠（tf に sync・inval・taskdef・appspec・canaryruns をまとめる）、
  ③ Amazon ECR（push）、④ AWS CodeDeploy（deploy）。
  束ねた線のラベルは EDGES の 1 行目を「・」でつないで改行したもので、新しい文言は作らない。
全体図から絞った要素: Amazon S3（frontend）（GitHub Actions からの線を ② に束ね、この図では線が無くなるため）。
ECS → RDS は運用側の表記「migration」（EDGES の migration）で描く。

配置: Region の中は 3 段（ALB・ECS・RDS の高さ）。左の列はデプロイで GitHub Actions から線を受ける要素と AWS FIS、
VPC の右は ECS が起動時・実行時に使う要素と canary の保存先、右端の列は canary → alarm → SNS の通知の流れ。
"""
import sys

from diagram_common import EDGES, Diagram

FS = 19
d = Diagram(fs=FS, fs_small=FS, fs_group=FS, hide_desc={"cloudfront"}, short_labels=True)


def joined(*eids):
    """EDGES の 1 行目を「・」でつなぎ、各「・」の後で改行する（文言は変えない）。edge() の line1 と breaks に渡す。"""
    parts = [EDGES[e][3] for e in eids]
    return "・".join(parts), tuple(p + "・" for p in parts[:-1])


# ---- 座標（絶対） ----
R1, R2, R3, R4 = 425, 640, 855, 930       # R1〜R3 は ALB・ECS・RDS の高さ（右の列も同じ）。R4 は AWS FIS
R3S, R5 = 905, 1115                       # SNS（CloudWatch の説明が 5 行のため下げる）、監査系の段
XA, XC, XD = 414, 1165, 1382              # 左の列・VPC の右の列・右端の列
LS, LP, LE, LT = 610, 625, 640, 655       # 左の列と VPC の間の縦のレーン（cd_s3・pull・cd_ecs・stoptask）
LCA, LN, LM = 1222, 1280, 1292            # 右の 2 列の間の縦のレーン（cd_alarm・notify・metric）
LSC = XD + 100                            # alarm の右のレーン（stopcond）
V0 = 670                                  # VPC の左端
S0, SW = V0 + 15, 320                     # subnet の左端と幅
V1 = S0 + SW + 15                         # VPC の右端
VX = 840                                  # CloudFront・ALB・ECS・RDS を縦一直線に置く x
LMG = S0 + SW - 15                        # migration の縦のレーン（data subnet の枠名の右、VPC の中）
AWS_X, RT = 268, 250                      # AWS Cloud の左端、Region の上端
RB = 1245                                 # Region の下端
YB = 1015                              # stopcond の下の横線
RR = LSC + 18                             # Region の右端

d.text("title", "デプロイ・監視・監査・Game Day・バックアップ", -25, 0, 700, 36, 25, bold=True)
d.group("aws", AWS_X, 52, RR + 15 - AWS_X, RB + 15 - 52)
d.group("region", AWS_X + 15, RT, RR - AWS_X - 15, RB - RT, parent="aws")
d.group("vpc", V0, RT + 57, V1 - V0, R3 + 118 - RT - 57, parent="region")
d.group("pub", S0, RT + 92, SW, 180, parent="vpc")
d.group("app", S0, RT + 287, SW, 200, parent="vpc")
d.group("data", S0, RT + 510, SW, 193, parent="vpc")

# AWS の外
d.node("gha", 52, R1)
d.node("dev", 52, R4)
d.node("email", XD + 70, RB + 92)
# AWS Cloud（Region の外）
d.node("sts", 600, 125, parent="aws")
d.node("cloudfront", VX, 140, parent="aws")
# Region
d.node("codedeploy", XA, R1, parent="region", label_width=170)
d.node("s3_codedeploy", XA, 595, parent="region")
d.node("ecr", XA, 765, parent="region")
d.node("fis", XA, R4, parent="region")
d.node("alb", VX, R1, parent="pub")
d.node("ecs", VX, R2, parent="app")
d.node("rds", VX, R3, parent="data")
d.node("s3_canary", XC, R1, parent="region")
d.node("secrets", XC, R2, parent="region")
d.node("logs", XC + 20, R3, parent="region")
d.node("canary", XD, R1, parent="region", label_width=150)
d.node("alarm", XD, R2, parent="region", label_width=186)
d.node("sns", XD, R3S, parent="region")
# foundation の監査系（2026-11-14 ユーザー決定）。Region の下の段に横一列
d.node("s3_athena", 365, R5, parent="region")
d.node("athena", 610, R5, parent="region")
d.node("s3_cloudtrail", 815, R5, parent="region")
d.node("cloudtrail", 1010, R5, parent="region")
d.node("logs_cloudtrail", 1215, R5, parent="region", label_width=245)


def py(vid, side, r):
    """要素の左右の辺上の点の y。"""
    return d.port(vid, 0 if side == "l" else 1, r)[1]


def ry(y):
    """AWS Cloud 枠の左辺上の y を相対位置にする。"""
    return round((y - 52) / (RB + 15 - 52), 4)


# ---- GitHub Actions（4 本） ----
gx = lambda r: d.port("gha", r, 0)[0]
y_sts = d.center("sts")[1]
d.edge("oidc", (0.15, 0), (0, 0.5), points=[(gx(0.15), y_sts)], label_at=(420, y_sts))
Y2 = 300
TF = joined("tf", "sync", "inval", "taskdef", "appspec", "canaryruns")
# 束ねた線の終点は AWS Cloud 枠（create-invalidation の CloudFront が Region の外にあるため）
d.edge("tf", (0.55, 0), (0, ry(Y2)), points=[(gx(0.55), Y2)], label_at=(150, Y2), line1=TF[0], breaks=TF[1], tgt="aws")
d.edge("deploy", (1, 0.5), (0, 0.5), label_at=(177, R1))
y_ecr = d.center("ecr")[1]
d.edge("push", (1, 0.85), (0, 0.5), points=[(142, py("gha", "r", 0.85)), (142, y_ecr)], label_at=(205, y_ecr))
d.edge("gameday", (1, 0.5), (0, 0.5), label_at=(170, R4))

# ---- CodeDeploy ----
d.edge("cd_alb", (1, 0.5), (0, 0.5), label_at=(540, R1))
d.edge("cd_ecs", (1, 0.75), (0, 0.1), points=[(LE, py("codedeploy", "r", 0.75)), (LE, py("ecs", "l", 0.1))],
       label_at=(S0 + 55, py("ecs", "l", 0.1)), breaks=("task set の",))
d.edge("cd_s3", (1, 0.95), (1, 0.5), points=[(LS, py("codedeploy", "r", 0.95)), (LS, 595)], label_at=(531, 595))
d.edge("cd_alarm", (0.5, 0), (0, 0.5), points=[(XA, RT + 40), (LCA, RT + 40), (LCA, R2)],
       label_at=(1080, RT + 40))

# ---- ECS ----
d.edge("pull", (0, 0.6), (1, 0.5), points=[(LP, py("ecs", "l", 0.6)), (LP, y_ecr)], label_at=(522, y_ecr))
d.edge("secret", (1, 0.25), (0, 0.25), label_at=((V1 + XC - 39) / 2, py("ecs", "r", 0.25)), breaks=("起動時に",))
d.edge("applog", (1, 0.6), (0, 0.5), points=[(V1 + 25, py("ecs", "r", 0.6)), (V1 + 25, R3)],
       label_at=((V1 + 25 + XC + 20 - 39) / 2, R3))
# migration は VPC の中だけを通す（data subnet の枠名の右のレーン）
d.edge("migration", (1, 0.95), (1, 0.5), points=[(LMG, py("ecs", "r", 0.95)), (LMG, R3)],
       label_at=((d.port("rds", 1, 0.5)[0] + LMG) / 2, R3))

# ---- 監視・通知 ----
d.edge("monitor", (0.5, 0), (1, 0.5), points=[(XD, 140)], label_at=(XD, 300))
d.edge("artifacts", (0, 0.5), (1, 0.5), label_at=((LCA + XD - 39) / 2, R1), breaks=("実行結果の",))
d.edge("metric", (0, 0.85), (0, 0.15), points=[(LM, py("canary", "l", 0.85)), (LM, py("alarm", "l", 0.15))],
       label_at=(LM, 568))
d.edge("notify", (0, 0.85), (0, 0.2), points=[(LN, py("alarm", "l", 0.85)), (LN, py("sns", "l", 0.2))],
       label_at=(LN, 845))
d.edge("mail", (1, 0.85), (0.5, 0), points=[(XD + 70, py("sns", "r", 0.85))], label_at=(XD + 70, RB + 32))

# ---- Game Day ----
d.edge("stoptask", (1, 0.3), (0, 0.85), points=[(LT, py("fis", "r", 0.3)), (LT, py("ecs", "l", 0.85))],
       label_at=(538, py("fis", "r", 0.3)))
d.edge("stopcond", (1, 0.75), (1, 0.5), points=[(590, py("fis", "r", 0.75)), (590, YB), (LSC, YB), (LSC, R2)],
       label_at=(900, YB))

# ---- 監査 ----
d.edge("athena_result", (0, 0.5), (1, 0.5), label_at=((365 + 610) / 2, R5))
d.edge("athena_query", (1, 0.5), (0, 0.5), label_at=((610 + 815) / 2, R5))
d.edge("trail_s3", (0, 0.5), (1, 0.5), label_at=((815 + 1010) / 2, R5))
d.edge("trail_logs", (1, 0.5), (0, 0.5), label_at=((1010 + 1215) / 2, R5))

open(sys.argv[1], "w", encoding="utf-8").write(d.xml("operations"))
