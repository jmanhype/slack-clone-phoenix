defmodule SlackCloneWeb.AuthLive.LoginLive do
  use SlackCloneWeb, :live_view
  alias SlackClone.Accounts

  @impl true
  def mount(_params, _session, socket) do
    {:ok, 
     socket
     |> assign(:page_title, "Sign in to Slack")
     |> assign(:form, to_form(%{"email" => "", "password" => ""}))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-white flex flex-col">
      <!-- Header -->
      <header class="border-b border-gray-200">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="flex justify-between items-center h-16">
            <div class="flex items-center">
              <svg class="h-8 w-8" viewBox="0 0 54 54" fill="none" xmlns="http://www.w3.org/2000/svg">
                <path d="M11.5 21.5C11.5 19.01 13.51 17 16 17C18.49 17 20.5 19.01 20.5 21.5V33.5C20.5 35.99 18.49 38 16 38C13.51 38 11.5 35.99 11.5 33.5V21.5Z" fill="#36C5F0"/>
                <path d="M33.5 21.5C33.5 19.01 35.51 17 38 17C40.49 17 42.5 19.01 42.5 21.5V33.5C42.5 35.99 40.49 38 38 38C35.51 38 33.5 35.99 33.5 33.5V21.5Z" fill="#2EB67D"/>
                <path d="M21.5 11.5C19.01 11.5 17 13.51 17 16C17 18.49 19.01 20.5 21.5 20.5H33.5C35.99 20.5 38 18.49 38 16C38 13.51 35.99 11.5 33.5 11.5H21.5Z" fill="#ECB22E"/>
                <path d="M21.5 33.5C19.01 33.5 17 35.51 17 38C17 40.49 19.01 42.5 21.5 42.5H33.5C35.99 42.5 38 40.49 38 38C38 35.51 35.99 33.5 33.5 33.5H21.5Z" fill="#E01E5A"/>
              </svg>
              <span class="ml-3 text-2xl font-bold">slack</span>
            </div>
            <div class="flex items-center space-x-4">
              <a href="#" class="text-gray-600 hover:text-gray-900">Product</a>
              <a href="#" class="text-gray-600 hover:text-gray-900">Solutions</a>
              <a href="#" class="text-gray-600 hover:text-gray-900">Enterprise</a>
              <a href="#" class="text-gray-600 hover:text-gray-900">Resources</a>
              <a href="#" class="text-gray-600 hover:text-gray-900">Pricing</a>
            </div>
          </div>
        </div>
      </header>

      <!-- Sign in form -->
      <div class="flex-1 flex items-center justify-center py-12 px-4 sm:px-6 lg:px-8">
        <div class="max-w-md w-full">
          <div class="text-center mb-8">
            <h1 class="text-5xl font-bold text-gray-900 mb-2">Sign in to Slack</h1>
            <p class="text-gray-600">We suggest using the email address you use at work.</p>
          </div>

          <!-- OAuth buttons -->
          <div class="space-y-3 mb-6">
            <button class="w-full flex items-center justify-center px-4 py-3 border border-gray-300 rounded-lg shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50">
              <svg class="h-5 w-5 mr-2" viewBox="0 0 24 24">
                <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
                <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
                <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"/>
                <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"/>
              </svg>
              Sign in with Google
            </button>
            <button class="w-full flex items-center justify-center px-4 py-3 border border-gray-300 rounded-lg shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50">
              <svg class="h-5 w-5 mr-2" fill="currentColor" viewBox="0 0 20 20">
                <path d="M10 0C4.477 0 0 4.477 0 10c0 4.991 3.657 9.128 8.438 9.878v-6.987h-2.54V10h2.54V7.797c0-2.506 1.492-3.89 3.777-3.89 1.094 0 2.238.195 2.238.195v2.46h-1.26c-1.243 0-1.63.771-1.63 1.562V10h2.773l-.443 2.89h-2.33v6.988C16.343 19.128 20 14.991 20 10c0-5.523-4.477-10-10-10z"/>
              </svg>
              Sign in with Apple
            </button>
          </div>

          <div class="relative my-6">
            <div class="absolute inset-0 flex items-center">
              <div class="w-full border-t border-gray-300"></div>
            </div>
            <div class="relative flex justify-center text-sm">
              <span class="px-4 bg-white text-gray-500">OR</span>
            </div>
          </div>

          <!-- Email/Password form -->
          <.form for={@form} phx-submit="sign_in" class="space-y-4">
            <div>
              <input
                type="email"
                name="email"
                value={@form["email"].value}
                placeholder="name@work-email.com"
                class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-600 focus:border-transparent"
                required
              />
            </div>
            <div>
              <input
                type="password"
                name="password"
                value={@form["password"].value}
                placeholder="Password"
                class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-purple-600 focus:border-transparent"
                required
              />
            </div>
            <button
              type="submit"
              class="w-full flex justify-center py-3 px-4 border border-transparent rounded-lg shadow-sm text-sm font-bold text-white bg-purple-600 hover:bg-purple-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-purple-500"
            >
              Sign In with Email
            </button>
          </.form>

          <div class="mt-6 text-center">
            <a href="#" class="text-sm text-purple-600 hover:text-purple-700">
              Forgot password?
            </a>
          </div>

          <div class="mt-8 pt-8 border-t border-gray-200">
            <div class="text-center">
              <span class="text-gray-600">New to Slack?</span>
              <.link navigate={~p"/auth/register"} class="ml-1 font-medium text-purple-600 hover:text-purple-700">
                Create an account
              </.link>
            </div>
          </div>
        </div>
      </div>

      <!-- Footer -->
      <footer class="border-t border-gray-200 bg-white">
        <div class="max-w-7xl mx-auto py-6 px-4 sm:px-6 lg:px-8">
          <div class="flex items-center justify-center space-x-6 text-sm text-gray-500">
            <a href="#" class="hover:text-gray-900">Privacy</a>
            <a href="#" class="hover:text-gray-900">Terms</a>
            <a href="#" class="hover:text-gray-900">Contact Us</a>
            <div class="flex items-center">
              <svg class="h-4 w-4 mr-1" fill="currentColor" viewBox="0 0 20 20">
                <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM4.332 8.027a6.012 6.012 0 011.912-2.706C6.512 5.73 6.974 6 7.5 6A1.5 1.5 0 019 7.5V8a2 2 0 004 0 2 2 0 011.523-1.943A5.977 5.977 0 0116 10c0 .34-.028.675-.083 1H15a2 2 0 00-2 2v2.197A5.973 5.973 0 0110 16v-2a2 2 0 00-2-2 2 2 0 01-2-2 2 2 0 00-1.668-1.973z" clip-rule="evenodd"/>
              </svg>
              <select class="border-none bg-transparent text-sm focus:ring-0">
                <option>English (US)</option>
                <option>Español</option>
                <option>Français</option>
              </select>
            </div>
          </div>
        </div>
      </footer>
    </div>
    """
  end

  @impl true
  def handle_event("sign_in", %{"email" => email, "password" => password}, socket) do
    case Accounts.authenticate_user(email, password) do
      {:ok, user} ->
        {:ok, token, _claims} = SlackClone.Guardian.encode_and_sign(user)
        
        # Get first workspace for user
        workspace = SlackClone.Workspaces.get_user_first_workspace(user.id)
        
        {:noreply,
         socket
         |> put_flash(:info, "Welcome back!")
         |> push_navigate(to: ~p"/workspace/#{workspace.id}")}

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Invalid email or password")
         |> assign(:form, to_form(%{"email" => email, "password" => ""}))}
    end
  end
end