<!--
PR 标题格式：[报告] 名字 - 主题   /   [实验] 名字 - 编号 主题   /   [共享] 改了什么
写完请把不适用的部分删掉，不要留一堆空标题。
-->

## 这个 PR 做了什么

<!-- 一两句话。如果对应某个 issue，写 "Closes #12"。 -->

## 改动范围

- [ ] 报告正文 `reports/<!-- 名字 -->/report.md`
- [ ] 实验记录 `reports/<!-- 名字 -->/experiments/`
- [ ] 共享文档 `docs/`
- [ ] 脚本 `scripts/`
- [ ] 协作规范 / 模板

## 自查清单（提交前请自己先过一遍）

- [ ] **只动了我自己的目录**（或：动了共享文件，已在下面说明理由并 @ 了组长）
- [ ] 报告里每一条结论都能点开对应的 `experiments/` 证据
- [ ] 实验记录里贴了 `git rev-parse HEAD` 的输出，且等于基线 commit
- [ ] 环境描述与 [baseline.md](../baseline.md) 不冲突（K8s 版本、镜像 tag）
- [ ] 没有提交 kubeconfig、token、证书等凭据
- [ ] 没有提交超过 5MB 的文件（超了就登记到 `data/MANIFEST.md`）
- [ ] 已运行 `python3 scripts/build_index.py`，README 索引是最新的
- [ ] 没有复制粘贴别人报告里的段落（共享内容应引用 `docs/`）

## 怎么验证的

<!-- 贴出关键命令和结果。让 reviewer 能自己复现，而不是只能相信你。 -->

```bash
# 例：
# kubectl -n volcano-system get podgroup -w
# python3 scripts/build_index.py --check
```

## 失败的实验 / 已知问题

<!-- 老实说。这个 PR 里有没有"试了但没成功"的部分？有没有你不确定的结论？
     写在这里比让 reviewer 自己发现要好得多。 -->

## 需要谁看

<!-- @ 具体的人。CODEOWNERS 会自动加，但你可以指定"我要张三看第 4 章的数据"。 -->
