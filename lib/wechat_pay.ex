defmodule WechatPay do
  @moduledoc """
  WechatPay provide toolkit for Wechat Payment Platform.

  ### Setup

  You need to define you own pay module, then `use` WechatPay:

  ```elixir
  defmodule MyPay do
    use WechatPay

    @impl WechatPay.Behaviour
    def config do
      [
        env: :production,
        appid: "wx8888888888888888",
        mch_id: "1900000109",
        apikey: "192006250b4c09247ec02edce69f6a2d",
        ssl_cacert: File.read!("fixture/certs/rootca.pem"),
        ssl_cert: File.read!("fixture/certs/apiclient_cert.pem"),
        ssl_key: File.read!("fixture/certs/apiclient_key.pem")
      ]
    end
  end
  ```

  > NOTE: If your are using the `:sandbox` environment,
  > You have to run `mix wechat_pay.get_sandbox_signkey` to
  > fetch the Sandbox API Key.

  ### Payment methods

  When `use` WechatPay in `MyPay` module, it will generate following
  modules for you:

  - `MyPay.App` - Implements the `WechatPay.PaymentMethod.App` behaviour
  - `MyPay.JSAPI` - Implements the `WechatPay.PaymentMethod.JSAPI` behaviour
  - `MyPay.Native` - Implements the `WechatPay.PaymentMethod.Native` behaviour

  ### Plug

  WechatPay will also generate some [Plugs](https://github.com/elixir-plug/plug) to
  simplify the process of handling notification from Wechat's Payment Gateway:

  - `MyPay.Plug.Payment` - Implements the `WechatPay.Plug.Payment` behaviour
  - `MyPay.Plug.Refund` - Implements the `WechatPay.Plug.Refund` behaviour

  ### JSON Encoder

  By default, `WechatPay` use `Jason` to encode JSON, if you want to use `Poison`,
  you can configure `:wechat_pay` application with:

  ```elixir
  config :wechat_pay, :json_library, Poison
  ```
  """

  defmacro __using__(opts) do
    opts =
      opts
      |> Enum.into(%{})

    config_ast =
      case opts do
        %{otp_app: otp_app} ->
          quote do
            @behaviour WechatPay.Behaviour

            IO.warn(~s"""
            The `:otp_app` option is deprecated, please define a config function as below:

                defmodule #{__MODULE__} do
                  use WechatPay

                  @impl WechatPay.Behaviour
                  def config do
                    Application.get_env(:#{unquote(otp_app)}, #{__MODULE__})

                    # or some customize without using the Mix config.
                  end
                end
            """)

            def config do
              unquote(otp_app)
              |> Application.fetch_env!(__MODULE__)
            end
          end

        _ ->
          quote do
            @behaviour WechatPay.Behaviour
          end
      end

    module_ast =
      quote do
        # define module `MyModule.App`
        __MODULE__
        |> Module.concat(:App)
        |> Module.create(
          quote do
            use WechatPay.PaymentMethod.App, mod: unquote(__MODULE__)
          end,
          Macro.Env.location(__ENV__)
        )

        # define module `MyModule.JSAPI`
        __MODULE__
        |> Module.concat(:JSAPI)
        |> Module.create(
          quote do
            use WechatPay.PaymentMethod.JSAPI, mod: unquote(__MODULE__)
          end,
          Macro.Env.location(__ENV__)
        )

        # define module `MyModule.Native`
        __MODULE__
        |> Module.concat(:Native)
        |> Module.create(
          quote do
            use WechatPay.PaymentMethod.Native, mod: unquote(__MODULE__)
          end,
          Macro.Env.location(__ENV__)
        )

        # define module `MyModule.Plug.Payment` & `MyModule.Plug.Refund`
        if Code.ensure_loaded?(Plug) do
          [__MODULE__, :Plug, :Payment]
          |> Module.concat()
          |> Module.create(
            quote do
              use WechatPay.Plug.Payment, mod: unquote(__MODULE__)
            end,
            Macro.Env.location(__ENV__)
          )

          [__MODULE__, :Plug, :Refund]
          |> Module.concat()
          |> Module.create(
            quote do
              use WechatPay.Plug.Refund, mod: unquote(__MODULE__)
            end,
            Macro.Env.location(__ENV__)
          )
        end
      end

    [config_ast, module_ast]
  end
end
