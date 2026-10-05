# 协作规范（CONTRIBUTING）

> 这份文档是组内的"法律"。有异议就提 PR 改它，改完大家一起遵守。
> **不要靠微信群口头约定** —— 口头约定三天后一定失忆，而且新加入的人看不到。
>
> 新人第一件事：读完本文，然后按第 1 节把自己报告的骨架建起来。

---

## 0. 三条铁律

1. **每人一个目录，谁也别动别人的文件。**
   `reports/<你的名字>/` 只有你能改。共享内容放 `docs/`，由组长或指定作者维护。
   这条规则存在的意义：避免"两个人同时改同一份文档"造成的冲突和互相覆盖。

2. **一条结论必须能追到一条证据。**
   报告里每个数字、每句"实测发现"，后面都要能点开对应的 `experiments/*.md`，
   里面必须有**原始命令**和**原始输出**。
   这是"测试报告"和"读后感"的区别，也是老师唯一会追问的地方。

3. **`main` 分支禁止直推。**
   所有改动走 PR，至少 1 人 review 后合并。哪怕只是改个错别字。

---

## 1. 我要开始写我的报告

```bash
# 1. 拉仓库
git clone <本仓库地址> && cd volcano-analysis

# 2. 开分支（一定要开，不要直接在 main 上写）
git checkout -b report/<你的名字>/init

# 3. 建自己的目录
mkdir -p reports/<你的名字>/experiments reports/<你的名字>/assets
cp templates/report.md     reports/<你的名字>/report.md
cp templates/experiment.md reports/<你的名字>/experiments/001-<主题>.md
cp reports/_example/meta.yml reports/<你的名字>/meta.yml   # 然后改里面的内容

# 4. 提交并推送
git add -A
git commit -m "report(<你的名字>): 初始化报告骨架"
git push -u origin HEAD
# 5. 到 GitHub 网页上开 PR
```

然后运行 `python3 scripts/build_index.py`，它会自动把你这行加进根 `README.md` 的索引表
（**不要手改 README 里的表格**，手改会被下次生成覆盖）。

### `meta.yml` 的写法

只有下面这几个字段，值**不要换行、不要加引号以外的符号**：

```yaml
name: 张三
github: zhangsan
title: Volcano gang 插件在资源碎片场景下的公平性与饥饿问题
module: pkg/scheduler/plugins/gang
status: 进行中
updated: 2026-10-05
```

- `status` 只能是这四个值之一：`规划中` / `进行中` / `待评审` / `已完成`
- `updated` 用 `YYYY-MM-DD`
- 脚本不认识其他字段，写多了会被忽略（不会报错）

---

## 2. 分支命名

| 场景 | 分支名 | 例子 |
| --- | --- | --- |
| 写 / 改自己的报告 | `report/<名字>/<主题>` | `report/zhangsan/gang-starvation` |
| 做一次实验 | `exp/<名字>/<编号>-<主题>` | `exp/zhangsan/003-fragmentation` |
| 改共享脚本 / 共享文档 | `chore/<名字>/<主题>` | `chore/lisi/setup-kind-arm64` |
| 改本规范 / 流程 | `meta/<名字>/<主题>` | `meta/wangwu/pr-template` |

分支用完就删。合并方式统一用 **Squash merge**，保持 `main` 的提交历史一条一条干净。

---

## 3. 提交信息

格式：`<类型>(<范围>): <做了什么>`

| 类型 | 用途 |
| --- | --- |
| `report` | 报告正文 |
| `exp` | 实验记录与原始数据 |
| `docs` | 共享文档 |
| `chore` | 脚本、配置、CI |
| `meta` | 协作规范本身 |
| `fix` | 修正错误结论或笔误 |

例子：

```
report(zhangsan): 补充 gang 插件在 3 队列竞争下的饥饿复现步骤
exp(lisi): 记录 001 基线压测原始输出
chore(admin): setup-kind.sh 固定 K8s 节点镜像版本
fix(wangwu): 修正 002 实验中吞吐量单位错误（MB/s 误写为 Mb/s）
```

**一次提交只做一件事。** 报告和实验数据不要混在同一个提交里 —— 以后要追溯"这个结论是哪次实验得出的"会非常痛苦。

---

## 4. 一次实验怎么记

1. 文件名连续编号：`experiments/001-xxx.md`、`002-xxx.md`……不要跳号、不要重号。
2. 从 `templates/experiment.md` 复制，别自己发明格式。
3. 原始输出放在**同目录**：`experiments/001-xxx.log`。
   - 小于 1MB → 直接提交进 git
   - 大于 1MB → 传网盘 / Git LFS，然后在 `data/MANIFEST.md` 里登记文件名 + sha256 + 下载链接
4. **跑之前**先把 `git -C ~/learn/volcano rev-parse HEAD` 的结果和集群版本贴进实验记录。
   没有这两个值的实验记录，别人无法复现，等于没做。
5. 实验失败也是实验结果。**失败的实验照记**，写清楚现象和排查过程 —— 这在报告里是加分项，不要删。

---

## 5. PR 与评审

### 开 PR 时

- 标题：`[报告] 张三 - gang 插件饥饿问题分析`
- 用仓库自带的 PR 模板，把"做了什么 / 怎么验证的 / 需要谁看"填完
- 自己先 review 一遍 diff，再点提交

### 评审时（至少 1 人）

看这四件事，别的不用管：

- [ ] 结论有没有对应的 `experiments/` 证据？数字能不能对得上？
- [ ] 有没有和 `baseline.md` 冲突的环境描述（K8s 版本、镜像 tag）？
- [ ] 有没有抄别人报告里的段落没注明？共享章节应该引用 `docs/` 而不是复制
- [ ] 有没有把凭据、kubeconfig、超大日志提交进来？

评审意见分两级：`must fix`（必须改）和 `nit`（可改可不改）。作者也可以有理有据地反驳，讨论记录留在 PR 里就是最好的过程材料。

---

## 6. 不要提交的东西

`.gitignore` 已经覆盖了大部分，但请你自己也守住底线：

- **集群凭据**：`kubeconfig`、token、证书、`*secret*.yaml` —— 泄露了要重搭集群
- 大于 5MB 的文件（镜像 tar、完整日志、pprof）
- 被分析对象本身（`volcano/` 源码目录，它有自己的仓库）
- 别人的报告目录

提交前自查：

```bash
git status                       # 看看都改了啥
git diff --cached --stat         # 看看暂存区的文件大小
```

---

## 7. 遇到分歧怎么办：写 ADR

凡是"大家必须口径一致"的事情，都不要在群里吵，写一份 ADR（Architecture Decision Record）：

- 指标怎么算？（吞吐量按 Pod 数还是按 CPU 核数？等待时间从哪个时间戳算起？）
- 超时算不算失败？
- 用不用 GPU？如果没有 GPU，GPU 相关结论怎么降级说明？
- 换不换 K8s 版本？

模板在 `docs/adr/0000-template.md`，参考已经写好的 `docs/adr/0001-pin-baseline-version.md`。
写 ADR 只需要 10 分钟，但能省掉后期 10 小时的返工。

---

## 8. 每周节奏

| 时间 | 谁 | 做什么 |
| --- | --- | --- |
| 组会前 | 每个人 | 更新自己 `meta.yml` 的 `status` 和 `updated`；把本周实验记录提 PR |
| 组会前 | 组长 | 跑 `python3 scripts/build_index.py`，确认 README 索引最新，合并积压的 PR |
| 组会上 | 全员 | 过一遍索引表；确认下周要补的实验；有新分歧就当场决定写不写 ADR |
| 阶段末 | 组长 | 更新 `reports/00-汇总.md`，做横向对比 |

---

## 9. 关于"每个人一份报告"和"一份总报告"

两者不冲突，但要提前约定：

- 每份个人报告**必须能独立提交**（老师要收），所以结构要完整，用 `templates/report.md` 的章节。
- 同时，**背景 / 架构 / 术语 / 环境这几章不要在个人报告里各写一遍**。
  写在 `docs/` 里，个人报告引用（`[见 docs/01-architecture.md](../docs/01-architecture.md)`）。
  如果老师要求纸质报告必须自包含，就在最后定稿时把 `docs/` 的内容统一贴进去一次 ——
  但**源文件永远只有一份**。抄五遍的结果一定是五个版本互相矛盾。

- 汇总阶段由组长把各人结论提炼进 `reports/00-汇总.md`，形成一张横向对比表。
