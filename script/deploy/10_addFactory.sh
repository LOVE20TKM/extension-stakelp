source $network_dir/address.extension.center.params
source $network_dir/address.extension.factory.lp.params

cast_send $extensionCenterAddress "addFactory(address,address)()" $firstTokenAddress $extensionFactoryLpAddress