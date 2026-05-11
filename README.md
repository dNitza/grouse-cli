# grouse-cli

A command-line tool for publishing to your [Grouse](https://grouse.blog) blog. Supports multiple blogs, Micropub posting, and Liquid template syncing.

## Installation

```sh
brew tap dnitza/homebrew-tap
brew install grouse-cli
```

## Configuration

Blog credentials are stored in `~/.grouse.yaml`. Run `grouse auth` to set one up interactively, or create the file by hand:

```yaml
default: myblog

blogs:
  myblog:
    url: https://myblog.example.com
    token: your-api-token
  secondblog:
    url: https://second.example.com
    token: another-api-token
```

- **`default`** — the blog used when `--blog` is not specified. Automatically set when you only have one blog.
- **`blogs`** — a named map of blog entries. Each entry needs a `url` and a `token`.

## Commands

### `grouse auth` — add or update a blog

Prompts for a name, URL, and token, then writes to `~/.grouse.yaml`. If the blog name already exists its credentials are updated in place.

```
$ grouse auth
Blog name: myblog
URL (e.g. https://myblog.example.com): https://myblog.example.com
Token: ••••••••
Blog 'myblog' added in /Users/you/.grouse.yaml.
Default blog: myblog.
```

When adding a second blog you are asked whether to make it the new default.

### `grouse default [BLOG_NAME]` — switch the default blog

Pass a name directly, or omit it to pick from a numbered list:

```
$ grouse default
Available blogs (enter a number):
1.  myblog  (current default)
2.  secondblog

Switch default to: 2
Default blog set to 'secondblog'.
```

```
$ grouse default myblog
Default blog set to 'myblog'.
```

### `grouse post note [CONTENT]` — publish a short note

```sh
# Inline content
grouse post note "Just shipped something nice."

# Pipe from stdin
echo "Just shipped something nice." | grouse post note

# Open $EDITOR
grouse post note
```

| Flag | Description |
|------|-------------|
| `-t`, `--tags` | Comma-separated tags |
| `--draft` | Save as draft instead of publishing |
| `-b`, `--blog` | Blog to post to (overrides default) |

On success the URL of the new post is printed to stdout.

### `grouse post article [CONTENT]` — publish a long-form article

```sh
# Inline
grouse post article --title "My Post" "Body text here."

# From a Markdown file
grouse post article --title "My Post" --file post.md

# Fully interactive — prompts for all fields including $EDITOR for content
grouse post article --interactive
```

| Flag | Description |
|------|-------------|
| `-T`, `--title` | Article title (required unless `--interactive`) |
| `-s`, `--slug` | URL slug (auto-generated if omitted) |
| `-t`, `--tags` | Comma-separated tags |
| `-f`, `--file` | Read body from a file |
| `--draft` | Save as draft |
| `-i`, `--interactive` | Prompt for all fields |
| `-b`, `--blog` | Blog to post to (overrides default) |

### `grouse post bookmark URL` — save a bookmark

```sh
grouse post bookmark https://example.com/interesting-post
grouse post bookmark https://example.com/post --name "Great read" --tags reading,links --content "My notes."
```

| Flag | Description |
|------|-------------|
| `-n`, `--name` | Bookmark title |
| `-t`, `--tags` | Comma-separated tags |
| `-c`, `--content` | Optional notes |
| `-b`, `--blog` | Blog to post to (overrides default) |

### `grouse sync pull` — fetch Liquid templates

Downloads all custom templates from the server and writes them as `.liquid` files.

```sh
grouse sync pull                    # writes to ./templates
grouse sync pull --output ./themes  # custom directory
```

| Flag | Description |
|------|-------------|
| `-o`, `--output` | Output directory (default: `./templates`) |
| `-b`, `--blog` | Blog to sync (overrides default) |

### `grouse sync push` — upload Liquid templates

Reads all `.liquid` files from a directory and pushes them to the server.

```sh
grouse sync push                   # reads from ./templates
grouse sync push --input ./themes  # custom directory
```

| Flag | Description |
|------|-------------|
| `-i`, `--input` | Input directory (default: `./templates`) |
| `-b`, `--blog` | Blog to sync (overrides default) |

### `grouse sync watch` — watch and sync on save

Pulls the current templates then watches the directory, pushing any `.liquid` file the moment it is saved.

```sh
grouse sync watch                  # watches ./templates
grouse sync watch --dir ./themes   # custom directory
```

| Flag | Description |
|------|-------------|
| `-d`, `--dir` | Directory to watch (default: `./templates`) |
| `-b`, `--blog` | Blog to sync (overrides default) |

## Targeting a specific blog

Every command accepts `--blog NAME` (or `-b NAME`) to override the default for that one invocation:

```sh
grouse post note "Testing the new blog." --blog secondblog
grouse sync pull --blog secondblog --output ./secondblog-templates
```
