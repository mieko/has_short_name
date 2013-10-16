# has\_short\_name

`has_short_name` allows you to abbreviate user's names, hopefully in a culturally sensitive way.

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
```

## Contributing

I'd really like contributions to this gem, as I only have a vague set of rules that
hold for common, Anglo-centric names.  A good set of defaults that hold more globally
would be nice.  If this gem fucks up your name, or should bail instead of abbreviating
it, a patch, or even a descriptions of what the proper behaviour is appreciated.

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
