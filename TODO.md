# Todos

- [ ] Need an onboarding flow
- [ ] Automatic DNS mapping for canineapp.run
- [ ] Show ingress logs at the cluster level -- parse NGINX logs
- [ ] Streaming logs for pods
- [ ] Project groupings?
- [ ] Constantly refresh the processes page for readiness of pods
- [ ] Support GPU backed clusters
- [ ] Make accidental deletions harder
- [ ] Allow creating a one off pod even if there are no services or deployments yet.
- [ ] Automatically detect node architecture for build target
- [ ] Failing to add webhooks to projects in different organizations.
- [ ] Github filtering across organizations is not working
- [ ] Explore allowing local PC's on DHCP to be a host
- [ ] Deployments API
- [ ] Pull request preview apps
- [ ] Update vocabulary on landing page
- [ ] Clear our historical logs
- [ ] log drain from application
- [ ] Check the pods in the namespace and ensure they are running. - app/services/k8/build_cloud_manager.rb
- [ ] Handle stuck helm `pending-upgrade` releases — detect and rollback before retrying in `K8::Helm::Client#install`

## Agent computers

- [x] Lifecycle: stop/start from the UI
- [ ] Lifecycle: stop idle computers automatically (nobody connected for a while); start on connect
- [ ] Keep memory across Stop: hibernate inside the VM (`systemctl hibernate`; Omarchy already sets up a swapfile
      and `resume=`), with a forced shutdown as the fallback. Saved memory can't be restored at a different size.
- [ ] Agent control: a way for agents to see and drive the Omarchy (Wayland/Hyprland) desktop, e.g. hyprctl IPC,
      a screen-capture protocol, and virtual keyboard/pointer input; then accept Canine API tokens for it in
      `lib/agent_computer_proxy.rb` and add `/api/v1/agent_computers` (update the swagger specs)
- [ ] Share the Omarchy ISO across computers on a cluster instead of importing 6GB per computer
- [x] Watch a computer from a second tab (view-only, Selkies' #shared) and take control back when another tab takes over
- [ ] Several tabs controlling one desktop at once: Selkies secure mode (master token per computer, Canine provisions
      the /api/tokens table and adds ?token= in the proxy). Spike first: do two tabs sharing the mk_control token both
      get input?
