# has\_short\_name

`has_short_name` allows you to abbreviate user's names, hopefully in a
culturally sensitive way.

## Installation

Add this line to your application's Gemfile:

    gem 'has_short_name'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install has_short_name

## Usage

```ruby
class User < ActiveRecord::Base
  has_short_name
end

m1 = User.create(name: 'Mike Owens')

# m1 is unique on first name
m1.short_name # => "Mike"

m2 = User.create(name: 'Mike Tyson')

# Notices that "Mike" is no longer unique
m2.short_name # => "Mike T."

# To ease confusion, we'll adjust all "Mikes" to the same level
User.adjust_short_names!
m1.short_name # => "Mike O."
m2.short_name # => "Mike T."

# Let's make it annoying
m3 = User.create(name: 'Mike Mikerson')
User.adjust_short_names!

# Its bailed trying to be clever.
User.all.pluck(:short_name) => # ['Mike Owens', 'Mike Tyson', 'Mike Mikerson']
```

## Alternate columns
You can specify the columns used as a source and destination of a short
name with `:from` and and `:column`:

```ruby
class Usuario < BaseTable
  # Use the 'nombre' column to generate 'short_nombre'
  has_short_name from:   :nombre,
                 column: :short_nombre
end
```

`has_short_name` can be used on more than one set of [`:from`, `:column`]
tuples, if you find a reason to do so.

## `:only`

Sometimes you don't want a short name generated, for example, when you have a
"name" field that can contain a human's name, or a company name.  To prevent
"Internet Widgets Pty." from being shortened to "Internet" or "Internet P.",
you'll want something like:

```ruby
class User
  has_short_name only: -> { human? }

  # Alternatively:
  # has_short_name only: :human?
  # Which is converted to the same
end
```

In this case, `short_name_candidates` will only return a single `name`, and
after negotiating short names, it'll always win out, implying
`short_name = name`.

## Rules

`has_short_name` comes with a list of default rules, which are executed in
order.  (See `HasShortName::DEFAULT_RULES`).  These currently are anglo-centric,
but I'd like to expand them.  If you need a particular set of rules,
`has_short_name` accepts a `:rules` configuration option, which overrides the
defaults.

## Contributing

I'd really like contributions to this gem, as I only have a vague set of rules
that hold for common, Anglo-centric names.  A good set of defaults that hold
more globally would be nice.  If this gem fucks up your name, or should bail
instead of abbreviating it, a patch, or even a descriptions of what the proper
behaviour is appreciated.

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
