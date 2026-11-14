"""terraform-hannibal の構成図: 要素・枠名・線のラベルの共通定義と、drawio XML の生成器。

全体図（build_architecture.py）と観点ごとの図（build_request_flow.py・build_operations.py）が import する。
名前・アイコン・ラベルの文言はこのファイルだけで定義し、図ごとのスクリプトで上書きしない。
"""
from xml.sax.saxutils import escape

FONT = "Helvetica,Arial,IPAPGothic,Hiragino Sans,Yu Gothic,Meiryo,sans-serif"

MAIN_COLOR = "#D45B07"   # 番号付きの流れ
OTHER_COLOR = "#545B64"  # その他の通信
DESC_COLOR = "#545B64"

_ICON_BASE = ("sketch=0;outlineConnect=0;fontColor=#232F3E;gradientColor=none;dashed=0;"
              "verticalLabelPosition=bottom;verticalAlign=top;align=center;html=1;whiteSpace=nowrap;"
              "fontStyle=0;aspect=fixed;")


def _res(res_icon, fill):
    return _ICON_BASE + f"fillColor={fill};strokeColor=#ffffff;shape=mxgraph.aws4.resourceIcon;resIcon=mxgraph.aws4.{res_icon};"


def _shape(shape, fill):
    return _ICON_BASE + f"fillColor={fill};strokeColor=none;pointerEvents=1;shape=mxgraph.aws4.{shape};"


# style 名は drawio の shape 索引（find-shapes.js）で実在を確認したもの
ICON_STYLES = {
    "cloudfront": (_res("cloudfront", "#8C4FFF"), 78, 78),
    "route53": (_res("route_53", "#8C4FFF"), 78, 78),
    "alb": (_shape("application_load_balancer", "#8C4FFF"), 78, 78),
    "ecs": (_res("ecs", "#ED7100"), 78, 78),
    "ecr": (_res("ecr", "#ED7100"), 78, 78),
    "rds": (_res("rds", "#C925D1"), 78, 78),
    "secrets": (_res("secrets_manager", "#DD344C"), 78, 78),
    "s3": (_res("s3", "#7AA116"), 78, 78),
    "codedeploy": (_res("codedeploy", "#C925D1"), 78, 78),
    "fis": (_res("fault_injection_simulator", "#C925D1"), 78, 78),
    "sns": (_res("sns", "#E7157B"), 78, 78),
    "logs": (_shape("cloudwatch_logs", "#E7157B"), 78, 58),
    "alarm": (_shape("alarm", "#E7157B"), 78, 78),
    "synthetics": (_shape("cloudwatch_synthetics", "#E7157B"), 78, 77),
    "sts": (_shape("sts", "#DD344C"), 78, 50),
    "client": (_shape("client", "#232F3D"), 78, 76),
    "user": (_shape("user", "#232F3D"), 78, 78),
    "email": (_shape("email_2", "#232F3D"), 78, 49),
    "internet": (_ICON_BASE + "strokeColor=#232F3E;fillColor=#ffffff;shape=mxgraph.aws4.resourceIcon;resIcon=mxgraph.aws4.internet;", 78, 78),
    "cloudtrail": (_res("cloudtrail", "#E7157B"), 78, 78),
    "athena": (_res("athena", "#8C4FFF"), 78, 78),
    "github": ("dashed=0;outlineConnect=0;html=1;align=center;labelPosition=center;verticalLabelPosition=bottom;"
               "verticalAlign=top;whiteSpace=nowrap;shape=mxgraph.weblogos.github;", 78, 78),
}

_GROUP_BASE = ("outlineConnect=0;gradientColor=none;html=1;whiteSpace=wrap;fontStyle=1;container=1;pointerEvents=0;"
               "collapsible=0;recursiveResize=0;shape=mxgraph.aws4.group;verticalAlign=top;align=left;spacingLeft=30;")
GROUP_STYLES = {
    "aws_cloud": _GROUP_BASE + "grIcon=mxgraph.aws4.group_aws_cloud;strokeColor=#232F3E;fillColor=none;fontColor=#232F3E;dashed=0;",
    "region": _GROUP_BASE + "grIcon=mxgraph.aws4.group_region;strokeColor=#00A4A6;fillColor=none;fontColor=#147EBA;dashed=1;",
    "vpc": _GROUP_BASE + "grIcon=mxgraph.aws4.group_vpc2;strokeColor=#8C4FFF;fillColor=none;fontColor=#8C4FFF;dashed=0;",
    "public": _GROUP_BASE + "grIcon=mxgraph.aws4.group_security_group;grStroke=0;strokeColor=#7AA116;fillColor=#F2F6E8;fontColor=#248814;dashed=0;",
    "private": _GROUP_BASE + "grIcon=mxgraph.aws4.group_security_group;grStroke=0;strokeColor=#00A4A6;fillColor=#E6F6F7;fontColor=#147EBA;dashed=0;",
}

# 枠名（英語・sentence case）
GROUPS = {
    "aws": ("aws_cloud", "AWS Cloud"),
    "region": ("region", "Region: ap-northeast-1"),
    "vpc": ("vpc", "VPC"),
    "pub": ("public", "Public subnet (2 AZs)"),
    "app": ("private", "Private subnet (app, 2 AZs)"),
    "data": ("private", "Private subnet (data, 2 AZs)"),
}

# 要素: id -> (アイコン, サービス名, 説明)。説明はこのシステム固有の情報だけ
NODES = {
    "browser": ("client", "ブラウザ", "React SPA"),
    "mapbox": ("internet", "Mapbox", "衛星画像・地形"),
    "gha": ("github", "GitHub Actions", "deploy（手動実行）"),
    "dev": ("user", "開発者端末", ""),
    "route53": ("route53", "Amazon Route 53", "alias record"),
    "cloudfront": ("cloudfront", "Amazon CloudFront", "geo restriction: JP"),
    "sts": ("sts", "AWS Security Token Service", "(AWS STS)"),
    "s3_frontend": ("s3", "Amazon S3", "frontend"),
    "alb": ("alb", "Application Load Balancer", "target group: blue / green<br>ACM 証明書"),
    "ecs": ("ecs", "Amazon ECS", "AWS Fargate"),
    "rds": ("rds", "Amazon RDS for PostgreSQL", "automated backups 保持 7 日"),
    "ecr": ("ecr", "Amazon ECR", ""),
    "secrets": ("secrets", "AWS Secrets Manager", "RDS 管理の DB 認証情報"),
    "logs": ("logs", "Amazon CloudWatch Logs", "ECS のアプリログ・保持 7 日"),
    "codedeploy": ("codedeploy", "AWS CodeDeploy", "blue/green・automatic rollbacks"),
    "s3_codedeploy": ("s3", "Amazon S3", "CodeDeploy 用（AppSpec）"),
    "alarm": ("alarm", "Amazon CloudWatch", "alarm ×16・dashboard<br>対象: ECS・RDS・ALB・canary・<br>CloudTrail のログ（metric filter）"),
    "sns": ("sns", "Amazon SNS", "topic ×2"),
    "email": ("email", "email", ""),
    "canary": ("synthetics", "CloudWatch Synthetics", "canary（5 分ごと）"),
    "s3_canary": ("s3", "Amazon S3", "canary 用"),
    "fis": ("fis", "AWS Fault Injection Service", "Game Day"),
    # foundation の監査系（2026-11-14 ユーザー決定で operations と全体図に追加）
    "cloudtrail": ("cloudtrail", "AWS CloudTrail", "single-Region"),
    "s3_cloudtrail": ("s3", "Amazon S3", "CloudTrail 用"),
    "logs_cloudtrail": ("logs", "Amazon CloudWatch Logs", "CloudTrail のログ・保持 30 日<br>metric filter ×4"),
    "athena": ("athena", "Amazon Athena", ""),
    "s3_athena": ("s3", "Amazon S3", "Athena の結果用"),
}

# 線: id -> (通信元, 通信先, 種類, 1 行目, 2 行目)
#   種類 main = 番号付きの流れ、req = 要求の流れ（番号なし。C4 の形）、ops = 運用の線（目的と手段）
EDGES = {
    "e1": ("browser", "cloudfront", "main", "① 静的ファイルの取得", "[HTTPS]"),
    "e2": ("cloudfront", "s3_frontend", "main", "② origin request", "[HTTPS, OAC]"),
    "e3": ("browser", "cloudfront", "main", "③ GraphQL の要求", "[JSON/HTTPS]"),
    "e4": ("cloudfront", "alb", "main", "④ GraphQL の要求の転送", "[JSON/HTTPS]"),
    "e5": ("alb", "ecs", "main", "⑤ GraphQL の要求の転送", "[JSON/HTTP]"),
    "e6": ("browser", "mapbox", "main", "⑥ 地図タイルの取得", "[HTTPS]"),
    "dns": ("browser", "route53", "req", "名前解決", "[DNS]"),
    "db": ("ecs", "rds", "req", "routes の取得・migration", "[PostgreSQL protocol/TLS]"),
    "migration": ("ecs", "rds", "ops", "migration", ""),  # operations 用（db と同じ通信の運用側の表記）
    "oidc": ("gha", "sts", "ops", "AssumeRoleWithWebIdentity", "（OpenID Connect）"),
    "tf": ("gha", "region", "ops", "terraform apply", ""),
    "sync": ("gha", "s3_frontend", "ops", "aws s3 sync", ""),
    "inval": ("gha", "cloudfront", "ops", "create-invalidation", ""),
    "push": ("gha", "ecr", "ops", "docker push", ""),
    "taskdef": ("gha", "ecs", "ops", "register-task-definition", ""),
    "appspec": ("gha", "s3_codedeploy", "ops", "aws s3 cp（AppSpec）", ""),
    "deploy": ("gha", "codedeploy", "ops", "create-deployment", ""),
    "canaryruns": ("gha", "canary", "ops", "GetCanaryRuns", ""),
    "cd_s3": ("codedeploy", "s3_codedeploy", "ops", "AppSpec の取得", ""),
    "cd_ecs": ("codedeploy", "ecs", "ops", "task set の作成・削除", ""),
    "cd_alb": ("codedeploy", "alb", "ops", "listener の切り替え", ""),
    "cd_alarm": ("codedeploy", "alarm", "ops", "alarm の参照", ""),
    "pull": ("ecs", "ecr", "ops", "image pull", ""),
    "secret": ("ecs", "secrets", "ops", "起動時に取得", ""),
    "applog": ("ecs", "logs", "ops", "awslogs", ""),
    "notify": ("alarm", "sns", "ops", "alarm action", ""),
    "mail": ("sns", "email", "ops", "subscription", ""),
    "monitor": ("canary", "cloudfront", "ops", "外形監視", ""),
    "artifacts": ("canary", "s3_canary", "ops", "実行結果の保存", ""),
    "metric": ("canary", "alarm", "ops", "metric の送信", ""),
    "gameday": ("dev", "fis", "ops", "StartExperiment", ""),
    "stoptask": ("fis", "ecs", "ops", "aws:ecs:stop-task", ""),
    "stopcond": ("fis", "alarm", "ops", "stop condition", ""),
    "trail_s3": ("cloudtrail", "s3_cloudtrail", "ops", "ログの配信", ""),
    "trail_logs": ("cloudtrail", "logs_cloudtrail", "ops", "ログの配信", ""),
    "athena_query": ("athena", "s3_cloudtrail", "ops", "ログの分析", ""),
    "athena_result": ("athena", "s3_athena", "ops", "クエリ結果の保存", ""),
}


# 観点ごとの図で使う短いラベル（全体図は EDGES の文言のまま。情報を落とさない）
SHORT_LABELS = {
    "e4": "④ GraphQL の転送",
    "e5": "⑤ GraphQL の転送",
    "db": "routes の取得",
}

# 観点ごとの図で使う短い説明（short_labels=True の図だけ。全体図は NODES の説明のまま）
SHORT_DESCS = {
    "alb": "target group: blue / green",
}


class Diagram:
    """座標はすべて絶対座標で受け取り、枠の入れ子では親からの相対座標に直して出力する。"""

    def __init__(self, fs=14, fs_small=12, fs_group=16, hide_desc=(), short_labels=False):
        """hide_desc: 説明（2 行目）を表示しない要素の id。short_labels: SHORT_LABELS と SHORT_DESCS を使う（観点ごとの図の表示設定）。"""
        self.fs, self.fs_small, self.fs_group = fs, fs_small, fs_group
        self.hide_desc, self.short_labels = set(hide_desc), short_labels
        self.cells = []      # (id, parent, xml)
        self.abs = {}        # id -> (x, y, w, h) 絶対
        self.parent = {}

    # ---- vertex ----
    def group(self, gid, x, y, w, h, parent="1"):
        kind, name = GROUPS[gid]
        self._vertex(gid, name, GROUP_STYLES[kind] + f"fontSize={self.fs_group};fontFamily={FONT};", x, y, w, h, parent)

    def node(self, nid, cx, cy, parent="1", label_width=None):
        """label_width を指定すると、その幅で折り返す（文言は変えない）。"""
        icon, name, desc = NODES[nid]
        if self.short_labels and nid in SHORT_DESCS:
            desc = SHORT_DESCS[nid]
        style, w, h = ICON_STYLES[icon]
        if label_width:
            style += f"whiteSpace=wrap;labelWidth={label_width};"
        label = escape(name)
        if desc and nid not in self.hide_desc:
            label += f'<br><span style="color:{DESC_COLOR}">{desc}</span>'
        self._vertex(nid, label, style + f"fontSize={self.fs};fontFamily={FONT};", cx - w / 2, cy - h / 2, w, h, parent)

    def text(self, tid, value, x, y, w, h, size, bold=False, align="left"):
        style = (f"text;html=1;whiteSpace=wrap;align={align};verticalAlign=middle;fontSize={size};"
                 f"fontStyle={1 if bold else 0};fontColor=#232F3E;fontFamily={FONT};")
        self._vertex(tid, value, style, x, y, w, h, "1")

    def _vertex(self, vid, value, style, x, y, w, h, parent):
        self.abs[vid] = (x, y, w, h)
        self.parent[vid] = parent
        px, py = (0, 0) if parent == "1" else self.abs[parent][:2]
        self.cells.append(
            f'<mxCell id="{vid}" value="{escape(value, {chr(34): "&quot;"})}" style="{style}" vertex="1" parent="{parent}">'
            f'<mxGeometry x="{x - px:.1f}" y="{y - py:.1f}" width="{w:.1f}" height="{h:.1f}" as="geometry"/></mxCell>')

    def center(self, vid):
        x, y, w, h = self.abs[vid]
        return x + w / 2, y + h / 2

    def port(self, vid, rx, ry):
        x, y, w, h = self.abs[vid]
        return x + rx * w, y + ry * h

    # ---- edge ----
    def edge(self, eid, exit, entry, points=(), label_at=None, src=None, tgt=None, line1=None, line2=None, kind=None,
             label_offset=None, breaks=()):
        """exit / entry は (rx, ry)。points は折れ点（絶対座標）。label_at は線上のラベル中心（絶対座標）。
        breaks: ラベルをこの文字列の直後で改行する（文言は変えない）。"""
        d_src, d_tgt, d_kind, d_l1, d_l2 = EDGES[eid]
        src, tgt, kind = src or d_src, tgt or d_tgt, kind or d_kind
        if self.short_labels and eid in SHORT_LABELS:
            d_l1 = SHORT_LABELS[eid]
        l1 = line1 if line1 is not None else d_l1
        l2 = line2 if line2 is not None else d_l2
        p0, p1 = self.port(src, *exit), self.port(tgt, *entry)
        path = [p0, *points, p1]
        rel = 0.0
        if label_at is not None:
            rel = _relative_pos(path, label_at)
        value = escape(l1)
        if l2:
            value += f'<br><span style="font-size:{self.fs_small}px">{escape(l2)}</span>'
        for br in breaks:
            value = value.replace(escape(br), escape(br) + "<br>", 1)
        if kind == "main":
            stroke = f"strokeColor={MAIN_COLOR};strokeWidth=3;fontColor=#232F3E;"
        else:
            stroke = f"strokeColor={OTHER_COLOR};strokeWidth=1.5;fontColor=#232F3E;"
        style = (f"edgeStyle=none;rounded=0;html=1;endArrow=block;endFill=1;endSize=7;{stroke}"
                 f"fontSize={self.fs};fontFamily={FONT};labelBackgroundColor=#ffffff;"
                 f"exitX={exit[0]};exitY={exit[1]};exitDx=0;exitDy=0;entryX={entry[0]};entryY={entry[1]};entryDx=0;entryDy=0;")
        pts = "".join(f'<mxPoint x="{x:.1f}" y="{y:.1f}"/>' for x, y in points)
        arr = f'<Array as="points">{pts}</Array>' if points else ""
        if label_offset:
            arr += f'<mxPoint x="{label_offset[0]}" y="{label_offset[1]}" as="offset"/>'
        self.cells.append(
            f'<mxCell id="{eid}" value="{escape(value, {chr(34): "&quot;"})}" style="{style}" edge="1" parent="1" source="{src}" target="{tgt}">'
            f'<mxGeometry x="{rel:.4f}" relative="1" as="geometry">{arr}</mxGeometry></mxCell>')

    # ---- 凡例 ----
    def legend(self, x, y, w=None, main=True):
        """矢印の向きの注記と線の種類だけ。main=False は番号付きの流れが無い図（見本線を 1 本にする）。"""
        fs = self.fs
        h = fs * 2 + 22
        w = w or fs * 52
        self._vertex("legend", "", "rounded=0;whiteSpace=wrap;html=1;fillColor=#ffffff;strokeColor=#879196;", x, y, w, h, "1")
        note = "凡例　矢印は通信の向き（通信を開始する側 → 受ける側）。応答は描かない"
        self.text("legend_note", note, x + 12, y + 6, w - 24, fs + 6, fs)
        yy = y + fs + 20
        seg = fs * 3.2
        kinds = ((MAIN_COLOR, 3, "番号付きの流れ（地図表示の主要なリクエスト）"), (OTHER_COLOR, 1.5, "その他の通信"))
        if not main:
            kinds = ((OTHER_COLOR, 1.5, "通信（運用の操作・監視・通知）"),)
        for i, (color, width, label) in enumerate(kinds):
            x0 = x + 12 + i * fs * 27
            self.cells.append(
                f'<mxCell id="legend_l{i}" value="" style="edgeStyle=none;html=1;endArrow=block;endFill=1;endSize=7;'
                f'strokeColor={color};strokeWidth={width};" edge="1" parent="1"><mxGeometry relative="1" as="geometry">'
                f'<mxPoint x="{x0:.1f}" y="{yy:.1f}" as="sourcePoint"/><mxPoint x="{x0 + seg:.1f}" y="{yy:.1f}" as="targetPoint"/>'
                f'</mxGeometry></mxCell>')
            self.text(f"legend_t{i}", label, x0 + seg + 8, yy - fs / 2 - 4, fs * 22, fs + 8, fs)

    def xml(self, name):
        body = "".join(self.cells)
        return (f'<mxfile host="drawio"><diagram id="{name}" name="{name}">'
                f'<mxGraphModel dx="0" dy="0" grid="0" gridSize="10" guides="1" tooltips="1" connect="1" arrows="1" '
                f'fold="1" page="0" pageScale="1" pageWidth="1600" pageHeight="900" math="0" shadow="0">'
                f'<root><mxCell id="0"/><mxCell id="1" parent="0"/>{body}</root></mxGraphModel></diagram></mxfile>\n')


def _relative_pos(path, pt):
    """折れ線 path 上の点 pt を drawio の edge label の x（-1..1、全長に対する位置）に変換する。"""
    total, best, acc = 0.0, None, 0.0
    segs = list(zip(path, path[1:]))
    lengths = [abs(b[0] - a[0]) + abs(b[1] - a[1]) if (a[0] == b[0] or a[1] == b[1])
               else ((b[0] - a[0]) ** 2 + (b[1] - a[1]) ** 2) ** 0.5 for a, b in segs]
    total = sum(lengths)
    for (a, b), ln in zip(segs, lengths):
        # pt から線分への射影
        dx, dy = b[0] - a[0], b[1] - a[1]
        t = 0.0 if ln == 0 else max(0.0, min(1.0, ((pt[0] - a[0]) * dx + (pt[1] - a[1]) * dy) / (dx * dx + dy * dy)))
        qx, qy = a[0] + t * dx, a[1] + t * dy
        dist = ((qx - pt[0]) ** 2 + (qy - pt[1]) ** 2) ** 0.5
        if best is None or dist < best[0]:
            best = (dist, acc + t * ln)
        acc += ln
    return best[1] / total * 2 - 1
